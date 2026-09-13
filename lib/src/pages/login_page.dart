import 'package:flutter/material.dart';

import '../../routes.dart';

class LoginPage extends StatelessWidget 
{
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      body: Center
      (
        child: Column
        (
          mainAxisAlignment: MainAxisAlignment.center,
          children: 
          [
            Text
            (
              'DropLyric',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
            SizedBox(height: 16),
            Text('Synchronize With'),
            SizedBox(height: 10),
            Row
            (
              spacing: 16,
              mainAxisAlignment: MainAxisAlignment.center,
              children: 
              [
                ElevatedButton
                (
                  onPressed: () 
                  {
                    Navigator.pushNamed(context, AppRoutes.mainPage);
                  },
                  child: Text('Spotify'),
                  style: ElevatedButton.styleFrom
                  (
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green,
                    disabledBackgroundColor: Colors.green.withAlpha(100),
                    disabledForegroundColor: Colors.white,
                    fixedSize: const Size(150, 45),
                  ),
                ),
                Text('or'),
                ElevatedButton
                (
                  onPressed: null,
                  child: Text('Youtube Music'),
                  style: ElevatedButton.styleFrom
                  (
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red.withAlpha(100),
                    disabledForegroundColor: Colors.white,
                    fixedSize: const Size(150, 45),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
