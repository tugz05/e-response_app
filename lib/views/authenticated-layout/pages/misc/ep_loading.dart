import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class EmergencyLoading extends StatelessWidget {
  const EmergencyLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 5, // Number of loading items to display
      itemBuilder: (context, index) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: AppColors.skeletonBase,
                highlightColor: AppColors.skeletonHighlight,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.skeletonBase,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer.fromColors(
                      baseColor: AppColors.skeletonBase,
                      highlightColor: AppColors.skeletonHighlight,
                      child: Container(
                        height: 16,
                        width: double.infinity,
                        color: AppColors.skeletonBase,
                      ),
                    ),
                    SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: AppColors.skeletonBase,
                      highlightColor: AppColors.skeletonHighlight,
                      child: Container(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: AppColors.skeletonBase,
                      ),
                    ),
                    SizedBox(height: 8),
                    Shimmer.fromColors(
                      baseColor: AppColors.skeletonBase,
                      highlightColor: AppColors.skeletonHighlight,
                      child: Container(
                        height: 12,
                        width: MediaQuery.of(context).size.width * 0.4,
                        color: AppColors.skeletonBase,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
