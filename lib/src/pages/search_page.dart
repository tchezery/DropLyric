import 'package:flutter/material.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      body: Center
      (
        child: Padding
        (
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column
          (
            mainAxisAlignment: MainAxisAlignment.start,
            children: 
            [
              Text(
                'Search', 
                style: TextStyle
                (
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextField
              (
                decoration: InputDecoration
                (
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder
                  (
                    borderRadius: BorderRadius.circular(10),
                  )
                ),
              ),
            ],
          )
        )
      ),
    );
  }
}