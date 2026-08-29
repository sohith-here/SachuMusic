import '../models/song.dart';
import 'music_repository.dart';

class CompositeMusicRepository implements MusicRepository {
  final List<MusicRepository> repositories;

  CompositeMusicRepository({required this.repositories});

  @override
  Future<List<Song>> getSongs() async {
    final results = await Future.wait(
      repositories.map((repository) => repository.getSongs()),
    );

    return results.expand((songs) => songs).toList();
  }
}
