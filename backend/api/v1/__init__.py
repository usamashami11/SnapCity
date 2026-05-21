from fastapi import APIRouter
from api.v1.report import router as report_router
from api.v1.godmode import router as godmode_router

v1_router = APIRouter()

# Assemble modular routers under v1
v1_router.include_router(report_router)
v1_router.include_router(godmode_router)
