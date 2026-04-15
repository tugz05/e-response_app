import 'package:flutter/material.dart';
import 'package:e_response_app_nemsu/theme/app_theme.dart';

class DrawerHeaderContent extends StatelessWidget {
  final String name;
  final String email;


  const DrawerHeaderContent({
    Key? key,
    required this.name,
    required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: AppColors.primary,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 5,),
              Icon(
                Icons.verified,
                color: AppColors.success,
                size: 18,
              ),
            ],
          ),
          SizedBox(height: 5),
          Text(
            '$email  |  09512558699',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
