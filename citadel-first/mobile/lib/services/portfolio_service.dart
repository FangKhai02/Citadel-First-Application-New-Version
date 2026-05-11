import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/bank_details.dart';
import '../models/transaction.dart';
import '../models/trust_dividend.dart';
import '../models/trust_payment_receipt.dart';
import '../models/trust_portfolio.dart';

class PortfolioService {
  final ApiClient _api = ApiClient();

  // ── Portfolios ───────────────────────────────────────────────────

  Future<List<TrustPortfolioDetail>> getMyPortfolios() async {
    final response = await _api.get(ApiEndpoints.portfoliosMe);
    final list = response.data['portfolios'] as List;
    return list
        .map((e) => TrustPortfolioDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrustPortfolioDetail> getPortfolioDetail(int id) async {
    final response = await _api.get(ApiEndpoints.portfolioDetail(id));
    return TrustPortfolioDetail.fromJson(response.data);
  }

  Future<TrustPortfolio> updatePortfolio(int id, Map<String, dynamic> data) async {
    final response = await _api.patch(ApiEndpoints.portfolioDetail(id), data: data);
    return TrustPortfolio.fromJson(response.data);
  }

  // ── Bank Details ─────────────────────────────────────────────────

  Future<List<BankDetails>> getMyBankDetails() async {
    final response = await _api.get(ApiEndpoints.bankDetailsMe);
    final list = response.data['banks'] as List;
    return list
        .map((e) => BankDetails.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BankDetails> createBankDetails(Map<String, dynamic> data) async {
    final response = await _api.post(ApiEndpoints.bankDetails, data: data);
    return BankDetails.fromJson(response.data);
  }

  Future<BankDetails> updateBankDetails(int id, Map<String, dynamic> data) async {
    final response = await _api.patch(ApiEndpoints.bankDetailUpdate(id), data: data);
    return BankDetails.fromJson(response.data);
  }

  Future<void> deleteBankDetails(int id) async {
    await _api.delete(ApiEndpoints.bankDetailUpdate(id));
  }

  Future<Map<String, String>> getBankProofUploadUrl({
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    final response = await _api.post(
      ApiEndpoints.bankProofUploadUrl,
      data: {'file_name': fileName, 'content_type': contentType},
    );
    return {
      'upload_url': response.data['upload_url'] as String,
      'key': response.data['key'] as String,
    };
  }

  Future<String> getBankProofDownloadUrl(int bankId) async {
    final response = await _api.get(ApiEndpoints.bankProofDownloadUrl(bankId));
    return response.data['upload_url'] as String;
  }

  // ── Transactions ─────────────────────────────────────────────────

  Future<List<TransactionVo>> getMyTransactions({String? type}) async {
    final url = type != null
        ? '${ApiEndpoints.transactionsMe}?type=$type'
        : ApiEndpoints.transactionsMe;
    final response = await _api.get(url);
    final list = response.data['transactions'] as List;
    return list
        .map((e) => TransactionVo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Dividends ────────────────────────────────────────────────────

  Future<List<TrustDividend>> getDividendsByPortfolio(int portfolioId) async {
    final response = await _api.get(ApiEndpoints.dividendByPortfolio(portfolioId));
    final list = response.data['dividends'] as List;
    return list
        .map((e) => TrustDividend.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Payment Receipts ─────────────────────────────────────────────

  Future<Map<String, String>> getPaymentReceiptUploadUrl(
    int orderId, {
    required String fileName,
    String contentType = 'application/pdf',
  }) async {
    final response = await _api.post(
      ApiEndpoints.paymentReceiptUploadUrl(orderId),
      data: {'file_name': fileName, 'content_type': contentType},
    );
    return {
      'upload_url': response.data['upload_url'] as String,
      'key': response.data['key'] as String,
    };
  }

  Future<TrustPaymentReceipt> confirmPaymentReceipt(int orderId, int receiptId) async {
    final response = await _api.post(
      ApiEndpoints.paymentReceiptConfirm(orderId),
      data: {'receipt_id': receiptId},
    );
    return TrustPaymentReceipt.fromJson(response.data);
  }

  Future<Map<String, dynamic>> submitPaymentReceipt(int orderId) async {
    final response = await _api.post(
      ApiEndpoints.paymentReceiptSubmit(orderId),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<TrustPaymentReceipt>> getPaymentReceipts(int orderId) async {
    final response = await _api.get(ApiEndpoints.paymentReceipts(orderId));
    final list = response.data['receipts'] as List;
    return list
        .map((e) => TrustPaymentReceipt.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── S3 Upload Helper ──────────────────────────────────────────────

  Future<void> uploadFileToS3(String presignedUrl, List<int> fileBytes, {String contentType = 'application/pdf'}) async {
    await Dio().put(
      presignedUrl,
      data: fileBytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'Content-Length': fileBytes.length,
        },
      ),
    );
  }

  // ── Receipt Download & Delete ─────────────────────────────────────

  Future<String> getPaymentReceiptDownloadUrl(int orderId, int receiptId) async {
    final response = await _api.get(ApiEndpoints.paymentReceiptDownloadUrl(orderId, receiptId));
    return response.data['upload_url'] as String;
  }

  Future<void> deletePaymentReceipt(int orderId, int receiptId) async {
    await _api.delete(ApiEndpoints.paymentReceiptDelete(orderId, receiptId));
  }

  // ── Bank Account Linking ──────────────────────────────────────────

  Future<TrustPortfolioDetail> linkBankAccount(int portfolioId, int bankDetailsId) async {
    final response = await _api.post(
      ApiEndpoints.portfolioLinkBank(portfolioId),
      data: {'bank_details_id': bankDetailsId},
    );
    return TrustPortfolioDetail.fromJson(response.data);
  }

  Future<TrustPortfolioDetail> unlinkBankAccount(int portfolioId) async {
    final response = await _api.delete(
      ApiEndpoints.portfolioUnlinkBank(portfolioId),
    );
    return TrustPortfolioDetail.fromJson(response.data);
  }
}