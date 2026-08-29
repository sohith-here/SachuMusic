import '../models/song.dart';
import '../repositories/local_music_repository.dart';

class MusicScanner {
  final LocalMusicRepository _repository = LocalMusicRepository();

  Future<List<Song>> scanSongs() {
    return _repository.getSongs();
  }
}
