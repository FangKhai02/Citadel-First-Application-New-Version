import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.trust_payment_receipt import TrustPaymentReceipt
from app.models.trust_portfolio import TrustPortfolio
from app.models.user import AppUser
from app.schemas.trust_payment_receipt import (
    TrustPaymentReceiptConfirmRequest,
    TrustPaymentReceiptListResponse,
    TrustPaymentReceiptResponse,
    TrustPaymentReceiptUploadRequest,
)
from app.schemas.user_details import PresignedUrlResponse
from app.services.s3_service import generate_presigned_upload_url, generate_presigned_download_url

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trust-orders", tags=["Trust Payment Receipts"])


@router.post(
    "/{order_id}/payment-receipt/upload-url",
    response_model=PresignedUrlResponse,
    summary="Generate presigned URL for payment receipt upload",
    description="Returns a presigned S3 URL to upload a payment receipt for a trust order.",
)
async def upload_payment_receipt_url(
    order_id: int,
    body: TrustPaymentReceiptUploadRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order belongs to the user
    from app.models.trust_order import TrustOrder
    order_result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No portfolio found for this trust order. Portfolio is created when the order is approved.",
        )

    # Generate presigned URL
    key = f"payment-receipts/{current_user.id}/{order_id}/{body.file_name}"
    upload_url = generate_presigned_upload_url(key=key, content_type=body.content_type)

    # Create a receipt record in DRAFT status
    receipt = TrustPaymentReceipt(
        trust_portfolio_id=portfolio.id,
        file_name=body.file_name,
        file_key=key,
        upload_status="DRAFT",
    )
    db.add(receipt)
    await db.commit()
    await db.refresh(receipt)

    logger.info("PAYMENT_RECEIPT_UPLOAD_URL user_id=%d order_id=%d receipt_id=%d", current_user.id, order_id, receipt.id)

    return PresignedUrlResponse(upload_url=upload_url, key=key)


@router.post(
    "/{order_id}/payment-receipt/confirm",
    response_model=TrustPaymentReceiptResponse,
    summary="Confirm payment receipt upload",
    description="Confirms that a payment receipt has been uploaded and updates its status to UPLOADED.",
)
async def confirm_payment_receipt(
    order_id: int,
    body: TrustPaymentReceiptConfirmRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Find the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found for this order.")

    # Find and update the receipt
    result = await db.execute(
        select(TrustPaymentReceipt).where(
            TrustPaymentReceipt.id == body.receipt_id,
            TrustPaymentReceipt.trust_portfolio_id == portfolio.id,
        )
    )
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment receipt not found.")

    receipt.upload_status = "UPLOADED"
    await db.commit()
    await db.refresh(receipt)

    logger.info("PAYMENT_RECEIPT_CONFIRMED receipt_id=%d order_id=%d", body.receipt_id, order_id)

    return TrustPaymentReceiptResponse.model_validate(receipt)


@router.get(
    "/{order_id}/payment-receipts",
    response_model=TrustPaymentReceiptListResponse,
    summary="List payment receipts for a trust order",
    description="Returns all payment receipts for a trust order.",
)
async def list_payment_receipts(
    order_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order belongs to the user
    from app.models.trust_order import TrustOrder
    order_result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        return TrustPaymentReceiptListResponse(receipts=[])

    # Get all receipts for this portfolio
    result = await db.execute(
        select(TrustPaymentReceipt).where(
            TrustPaymentReceipt.trust_portfolio_id == portfolio.id,
        ).order_by(TrustPaymentReceipt.created_at.desc())
    )
    receipts = result.scalars().all()

    return TrustPaymentReceiptListResponse(
        receipts=[TrustPaymentReceiptResponse.model_validate(r) for r in receipts]
    )


@router.get(
    "/{order_id}/payment-receipts/{receipt_id}/download-url",
    response_model=PresignedUrlResponse,
    summary="Get presigned download URL for a payment receipt",
    description="Returns a presigned S3 URL to download/view a payment receipt.",
)
async def get_receipt_download_url(
    order_id: int,
    receipt_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order belongs to the user
    from app.models.trust_order import TrustOrder
    order_result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the receipt
    result = await db.execute(
        select(TrustPaymentReceipt).where(TrustPaymentReceipt.id == receipt_id)
    )
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment receipt not found.")

    # Verify the receipt belongs to the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio or receipt.trust_portfolio_id != portfolio.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Receipt does not belong to this order.")

    download_url = generate_presigned_download_url(key=receipt.file_key, expires_in=300)

    logger.info("PAYMENT_RECEIPT_DOWNLOAD user_id=%d order_id=%d receipt_id=%d", current_user.id, order_id, receipt_id)

    return PresignedUrlResponse(upload_url=download_url, key=receipt.file_key)


@router.delete(
    "/{order_id}/payment-receipts/{receipt_id}",
    summary="Delete a payment receipt",
    description="Deletes a payment receipt record and its file from S3.",
)
async def delete_payment_receipt(
    order_id: int,
    receipt_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order belongs to the user
    from app.models.trust_order import TrustOrder
    order_result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the receipt
    result = await db.execute(
        select(TrustPaymentReceipt).where(TrustPaymentReceipt.id == receipt_id)
    )
    receipt = result.scalar_one_or_none()
    if not receipt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment receipt not found.")

    # Verify the receipt belongs to the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio or receipt.trust_portfolio_id != portfolio.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Receipt does not belong to this order.")

    # Delete the file from S3 (best-effort, don't fail if S3 delete fails)
    try:
        from app.services.s3_service import delete_s3_object
        delete_s3_object(receipt.file_key)
    except Exception:
        logger.warning("S3_DELETE_FAILED receipt_id=%d key=%s (continuing with DB delete)", receipt_id, receipt.file_key)

    # Delete from database
    await db.delete(receipt)
    await db.commit()

    logger.info("PAYMENT_RECEIPT_DELETED user_id=%d order_id=%d receipt_id=%d", current_user.id, order_id, receipt_id)

    return {"detail": "Payment receipt deleted successfully."}


@router.post(
    "/{order_id}/payment-receipt/submit",
    summary="Submit payment receipts for review",
    description="Submits uploaded payment receipts for Vanguard review. Sets portfolio payment_status to IN_REVIEW.",
)
async def submit_payment_receipt(
    order_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order belongs to the user
    from app.models.trust_order import TrustOrder
    order_result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No portfolio found for this trust order.",
        )

    # Idempotent: already in review
    if portfolio.payment_status == "IN_REVIEW":
        return {"message": "Payment receipt already submitted for review.", "payment_status": "IN_REVIEW"}

    # Validate portfolio is in PENDING payment status
    if portfolio.payment_status != "PENDING":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot submit for review. Current payment status: {portfolio.payment_status}",
        )

    # Validate at least one receipt is uploaded
    receipt_result = await db.execute(
        select(TrustPaymentReceipt).where(
            TrustPaymentReceipt.trust_portfolio_id == portfolio.id,
            TrustPaymentReceipt.upload_status == "UPLOADED",
        )
    )
    uploaded_receipts = receipt_result.scalars().all()
    if not uploaded_receipts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No uploaded payment receipts found. Please upload a receipt first.",
        )

    # Update payment status to IN_REVIEW
    portfolio.payment_status = "IN_REVIEW"
    await db.commit()
    await db.refresh(portfolio)

    logger.info("PAYMENT_RECEIPT_SUBMITTED user_id=%d order_id=%d portfolio_id=%d", current_user.id, order_id, portfolio.id)

    return {"message": "Payment receipt submitted for review.", "payment_status": "IN_REVIEW"}