import 'package:flutter/material.dart';
import '../services/lyric_service.dart';

class TrackPage extends StatefulWidget 
{
  final int id;
  
  const TrackPage({
    super.key,
    required this.id,
  });

  @override
  State<TrackPage> createState() => _TrackPageState();
}

class _TrackPageState extends State<TrackPage>
{
  final LyricService _lyricService = LyricService();
  Lyrics? _track;
  bool _isLoading = true;

  @override
  void initState()
  {
    super.initState();
    _loadTrack();
  }

  Future<void> _loadTrack() async 
  {
    final results = await _lyricService.getTrackById(widget.id);
    
    if (!mounted) return;

    setState(() 
    {
      _track = results.isNotEmpty ? results.first : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) 
  {
    return Scaffold
    (
      appBar: AppBar(),
      body: _isLoading
        ? const Center (child: CircularProgressIndicator())
        : _track == null
          ? const Center (child: Text('Track not found'))
          : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column
            (
              crossAxisAlignment: CrossAxisAlignment.start,
              children: 
              [
                Text(
                  _track!.trackName,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(_track!.artistName),
                const SizedBox(height: 16.0),
                SelectableText(
                  _track!.instrumental 
                    ? 'Instrumental Track' 
                    : _track!.plainLyrics,
                ),
              ],
            ),
          )
    );
  }
}