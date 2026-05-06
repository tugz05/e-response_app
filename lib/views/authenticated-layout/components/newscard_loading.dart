import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';
import 'package:shimmer/shimmer.dart';

class NewsCardLoading extends StatelessWidget {
  const NewsCardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.skeletonBase,
      highlightColor: AppColors.skeletonHighlight,
      child: Container(
        width: 200,
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              width: double.infinity,
              color: AppColors.skeletonBase,
            ),
            const SizedBox(height: 8.0),
            Container(
              height: 20,
              width: double.infinity,
              color: AppColors.skeletonBase,
            ),
            const SizedBox(height: 4.0),
            Container(
              height: 16,
              width: 100,
              color: AppColors.skeletonBase,
            ),
          ],
        ),
      ),
    );
  }
}
