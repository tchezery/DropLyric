import 'package:flutter/material.dart';
import '../services/lyric_service.dart';
import 'track_page.dart';

class SearchPage extends StatefulWidget 
{
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}


class _SearchPageState extends State<SearchPage>
{
  final LyricService _lyricService = LyricService();
  List<Lyrics> _searchResults = [];
  bool _isLoading = false;

  void _performSearch(String term) async 
  {
    if (term.trim().isEmpty) 
    {
      setState(() 
      {
        _searchResults = [];
      });
      return;
    }
    
    setState(() 
    {
      _isLoading = true;
    });
    
    final results = await _lyricService.searchByTerm(term);
    
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
  }


  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea
      (
        child: Padding
        (
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column
          (
            crossAxisAlignment: CrossAxisAlignment.start,
            children: 
            [ 
              const SizedBox(height: 60),
              TextField
              (
                onSubmitted: _performSearch,
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
              
              const SizedBox(height: 20),

              Expanded(
                child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'Nenhuma música encontrada.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final lyric = _searchResults[index];
                          return ListTile(
                            title: Text(lyric.trackName.isNotEmpty ? lyric.trackName : lyric.name),
                            subtitle: Text('${lyric.artistName} - ${lyric.albumName}'),
                            onTap: () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (_) => TrackPage(id: lyric.id),)
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          )
        )
      ),
    );
  }
}