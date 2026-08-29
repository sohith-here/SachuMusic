import '../models/song.dart';

abstract class MusicRepository {
  Future<List<Song>> getSongs();
}
