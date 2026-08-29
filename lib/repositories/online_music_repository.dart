import '../models/song.dart';
import 'music_repository.dart';

class OnlineMusicRepository implements MusicRepository {
  @override
  Future<List<Song>> getSongs() async {
    // Online music API will be connected here later.
    return [];
  }
}
