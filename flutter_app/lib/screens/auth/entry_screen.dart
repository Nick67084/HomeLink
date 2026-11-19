part of '../../main.dart';

class EntryScreen extends StatefulWidget { const EntryScreen({super.key}); @override State<EntryScreen> createState() => _EntryState(); }
class _EntryState extends State<EntryScreen> {
  bool loading = true;
  @override void initState() { super.initState(); restore(); }
  Future<void> restore() async {
    Api.token = await Api.storage.read(key: 'token');
    if (Api.token != null) {
      try { final user = await Api.request('GET', '/me');
        if(mounted) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Shell(user: Map<String,dynamic>.from(user)))); return; }
      } catch (_) { await Api.logout(); }
    }
    if(mounted) setState(() => loading = false);
  }
  @override Widget build(BuildContext context) => loading ? const Scaffold(body: Center(child: CircularProgressIndicator())) : const AuthScreen();
}

