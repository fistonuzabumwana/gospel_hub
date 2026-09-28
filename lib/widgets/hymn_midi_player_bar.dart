import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/original_hymn.dart';

class HymnMidiPlayerBar extends StatefulWidget {
  final List<OriginalHymn> originals;
  final Function(OriginalHymn)? onTrackChanged;

  const HymnMidiPlayerBar({
    super.key,
    required this.originals,
    this.onTrackChanged,
  });

  @override
  State<HymnMidiPlayerBar> createState() => HymnMidiPlayerBarState();
}

class HymnMidiPlayerBarState extends State<HymnMidiPlayerBar> {
  late AudioPlayer _player;
  OriginalHymn? _currentTrack;

  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _completeSubscription;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayerListeners();

    // If there is only one track with a valid MIDI file, auto-select it
    final validTracks = widget.originals.where((o) => o.midiAssetPath != null).toList();
    if (validTracks.length == 1) {
      _currentTrack = validTracks.first;
    }
  }

  void _initPlayerListeners() {
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          _isLoading = false;
        });
      }
    });

    _positionSubscription = _player.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSubscription = _player.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() => _duration = dur);
      }
    });

    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _position = Duration.zero;
          _playerState = PlayerState.stopped;
        });
      }
    });
  }

  @override
  void didUpdateWidget(HymnMidiPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.originals != oldWidget.originals) {
      _stopAndReset();
      final validTracks = widget.originals.where((o) => o.midiAssetPath != null).toList();
      if (validTracks.length == 1) {
        _currentTrack = validTracks.first;
      } else {
        _currentTrack = null;
      }
    }
  }

  Future<void> _stopAndReset() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _playerState = PlayerState.stopped;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _playTrack(OriginalHymn track) async {
    final assetPath = track.midiAssetPath;
    if (assetPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nta dosiye ya MIDI ihari kuri iyi ndirimbo.')),
      );
      return;
    }

    setState(() {
      _currentTrack = track;
      _isLoading = true;
    });

    widget.onTrackChanged?.call(track);

    try {
      await _player.stop();
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing MIDI: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ikosa mu gucuranga MIDI: $e')),
        );
      }
    }
  }

  void _onPlayPressed() {
    final validTracks = widget.originals.where((o) => o.midiAssetPath != null).toList();
    if (validTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nta muziki wa MIDI uhari kuri iyi ndirimbo.')),
      );
      return;
    }

    if (_playerState == PlayerState.playing) {
      _player.pause();
      return;
    }

    if (_playerState == PlayerState.paused) {
      _player.resume();
      return;
    }

    // If only one track exists, play it directly
    if (validTracks.length == 1) {
      _playTrack(validTracks.first);
      return;
    }

    // If multiple tracks exist and one is already loaded, resume/replay it
    if (_currentTrack != null) {
      _playTrack(_currentTrack!);
      return;
    }

    // If multiple tracks exist and none selected, ask the user with the actual song titles
    _showTrackSelectionDialog(validTracks);
  }

  void _showTrackSelectionDialog(List<OriginalHymn> tracks) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.music_note_rounded,
                          color: isDark ? const Color(0xFF60A5FA) : primaryColor, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Hitamo indirimbo wumva (MIDI)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                ...tracks.map((track) {
                  final isSelected = _currentTrack == track;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: (isDark ? const Color(0xFF60A5FA) : primaryColor)
                          .withValues(alpha: isSelected ? 0.25 : 0.1),
                      child: Icon(
                        isSelected ? Icons.play_arrow_rounded : Icons.audiotrack_rounded,
                        color: isDark ? const Color(0xFF60A5FA) : primaryColor,
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      track.language.isNotEmpty
                          ? '${track.language} version'
                          : 'Original tune',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle,
                            color: isDark ? const Color(0xFF60A5FA) : primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _playTrack(track);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = isDark ? const Color(0xFF60A5FA) : primaryColor;

    final validTracks = widget.originals.where((o) => o.midiAssetPath != null).toList();
    if (validTracks.isEmpty) return const SizedBox.shrink();

    final isPlaying = _playerState == PlayerState.playing;

    final maxVal = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final curVal = _position.inMilliseconds.toDouble().clamp(0.0, maxVal);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row: Track title and track-switcher chip
          Row(
            children: [
              Icon(Icons.piano_rounded, size: 20, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentTrack != null
                      ? _currentTrack!.title
                      : (validTracks.length > 1
                          ? 'Hitamo indirimbo wumva'
                          : validTracks.first.title),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (validTracks.length > 1) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showTrackSelectionDialog(validTracks),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentTrack?.language.isNotEmpty == true
                              ? _currentTrack!.language
                              : 'Guhindura',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_drop_down, size: 16, color: accentColor),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Player controls and slider row
          Row(
            children: [
              // Play/Pause button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                icon: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        size: 38,
                        color: accentColor,
                      ),
                onPressed: _onPlayPressed,
              ),
              const SizedBox(width: 6),

              // Progress slider
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                    activeTrackColor: accentColor,
                    inactiveTrackColor: accentColor.withValues(alpha: 0.2),
                    thumbColor: accentColor,
                  ),
                  child: Slider(
                    value: curVal,
                    min: 0.0,
                    max: maxVal,
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),

              // Time indicator
              Text(
                _duration > Duration.zero
                    ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                    : _formatDuration(_position),
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
