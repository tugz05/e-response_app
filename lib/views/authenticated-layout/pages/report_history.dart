import 'dart:convert';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionHistory extends StatefulWidget {
  const TransactionHistory({super.key});

  @override
  State<TransactionHistory> createState() => _TransactionHistoryState();
}

class _TransactionHistoryState extends State<TransactionHistory> {
  List<dynamic> transactions = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('id');
      if (userId == null) {
        setState(() {
          error = "User ID not found.";
          isLoading = false;
        });
        return;
      }
      final url = 'https://cdrrmo-tandag.com/api/v1/report-history/$userId';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data is Map && data['data'] is List)
            ? data['data'] as List
            : [];
        setState(() {
          transactions = items;
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Failed to fetch transactions (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  String formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy h:mm a').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      backgroundColor: AppColors.background,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.accent),
                  ),
                )
              : transactions.isEmpty
                  ? const Center(child: Text("No transactions found."))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      separatorBuilder: (_, __) => const Divider(height: 25),
                      itemBuilder: (context, idx) {
                        final tx = transactions[idx];
                        final type = tx['type'] ?? 'N/A';
                        final status = tx['status'] ?? 'N/A';
                        final details = tx['details'] ?? '';
                        final address = tx['address'] ?? '';
                        final createdAt = tx['created_at'] ?? '';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Icon(
                              type.toLowerCase() == "message" ? Icons.message : Icons.call,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            type,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (details.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text("Details: $details"),
                                ),
                              if (address.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text("Address: $address"),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "Status: $status",
                                  style: TextStyle(
                                    color: status.toLowerCase() == "pending"
                                        ? AppColors.warning
                                        : status.toLowerCase() == "completed"
                                            ? AppColors.success
                                            : AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  "Date: ${formatDate(createdAt)}",
                                  style: const TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
