from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Union
from pydantic import BaseModel, Field
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langserve import add_routes
from llm import llm as model
import fitz  # PyMuPDF
from langchain_community.embeddings.huggingface import HuggingFaceEmbeddings
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough
from langchain_core.messages import ChatMessage
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores.faiss import FAISS
from langchain.schema import Document
from langchain.retrievers import EnsembleRetriever
from langchain_teddynote.retrievers import KiwiBM25Retriever

app = FastAPI()

def perform_rag(question: str):
    # PDF에서 데이터 읽기
    doc = fitz.open("/home/bj/DU_chatbot_project-main/app/QADataset.pdf")
    text = ""
    for page in doc:
        text += page.get_text()

    # 텍스트 분할
    splitter = RecursiveCharacterTextSplitter(chunk_size=100, chunk_overlap=50)
    chunks = [Document(page_content=t) for t in splitter.split_text(text)]

    # Loading Embedding model
    model_kwargs = {"device": "cuda"}
    encode_kwargs = {"normalize_embeddings": True}
    embeddings = HuggingFaceEmbeddings(
        model_name="intfloat/multilingual-e5-large",
        model_kwargs=model_kwargs,
        encode_kwargs=encode_kwargs,
    )

    # Create EnsembleRetriever
    db = FAISS.from_documents(chunks, embedding=embeddings)
    faiss = db.as_retriever()
    kiwi_bm25_retriever = KiwiBM25Retriever.from_documents(chunks)

    retriever = EnsembleRetriever(
                                    retrievers=[kiwi_bm25_retriever, faiss],
                                    weights=[0.5, 0.5],
                                    search_type="mmr",
                                    )
    # 컨텍스트 추출
    context = retriever.get_relevant_documents(question)
    return "\n\n".join(doc.page_content for doc in context)

def query_llm(context: str, question: str):
    # HumanMessage 형식으로 입력 메시지 생성
    message = HumanMessage(content=
                           f"""다음 정보를 바탕으로 질문에 답하세요:
                                {context}

                                질문:
                                {question}

                                질문의 핵심만 파악하여 간결하게 1-2문장으로 답변하고, 불필요한 대답은 하지 마세요.

                                답변:""")
    response = model([message])  # LLM 모델 호출 (리스트 형태로 전달)
    return response.content  # 응답 내용 반환

class QueryRequest(BaseModel):
    question: str

@app.post("/rag-query")
async def rag_query(request: QueryRequest):
    try:
        # RAG 컨텍스트 생성
        context = perform_rag(request.question)
        # LLM 쿼리로 응답 생성
        answer = query_llm(context, request.question)
        # 결과 반환 (컨텍스트 포함)
        return {
            "question": request.question,
            "context": context,
            "answer": answer
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
    
# ngrok http --url=lenient-topical-gopher.ngrok-free.app 8080