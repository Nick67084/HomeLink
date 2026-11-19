part of '../../main.dart';

class AuthScreen extends StatefulWidget { const AuthScreen({super.key}); @override State<AuthScreen> createState() => _AuthState(); }
class _AuthState extends State<AuthScreen> {
  bool register = false, busy = false;
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController(), name = TextEditingController(), phone = TextEditingController(), building = TextEditingController(), unit = TextEditingController();
  @override void dispose() { for(final c in [email,password,name,phone,building,unit]) { c.dispose(); } super.dispose(); }
  Widget field(TextEditingController c, String label, {bool secret = false}) => Padding(padding: const EdgeInsets.only(bottom: 13), child: TextFormField(controller: c, obscureText: secret,
    decoration: InputDecoration(labelText: label), validator: (v) => (v == null || v.trim().isEmpty) ? '$label required' : (secret && v.length < 8 ? 'At least 8 characters' : null)));
  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      if (register) {
        await Api.request('POST', '/auth/register', {'full_name':name.text.trim(),'email':email.text.trim(),'phone':phone.text.trim(),'password':password.text,'building':building.text.trim(),'unit_number':unit.text.trim()});
        if(mounted) {toast(context,'Registered. Ask juristic staff to approve your account.');setState(()=>register=false);}
      } else {
        final result = await Api.request('POST','/auth/login',{'email':email.text.trim(),'password':password.text});
        Api.token = result['token']; await Api.storage.write(key:'token',value:Api.token);
        final user = await Api.request('GET','/me');
        if(mounted) Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>Shell(user:Map<String,dynamic>.from(user))));
      }
    } catch(e) { if(mounted) toast(context,err(e)); } finally { if(mounted)setState(()=>busy=false); }
  }
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(padding:const EdgeInsets.all(26),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),child:Form(key:form,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    const Icon(Icons.home_work_rounded,size:68,color:navy),const SizedBox(height:10),const Text('HomeLink',textAlign:TextAlign.center,style:TextStyle(fontSize:34,fontWeight:FontWeight.bold,color:navy)),
    const Text('Your community, one app.',textAlign:TextAlign.center,style:TextStyle(color:ocean)),const SizedBox(height:35),
    Text(register?'Create resident account':'Welcome back',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold,color:navy)),const SizedBox(height:18),
    if(register)...[field(name,'Full name'),field(phone,'Phone'),field(building,'Building (e.g. A)'),field(unit,'Unit number (e.g. 1205)')],
    field(email,'Email'),field(password,'Password',secret:true),const SizedBox(height:8),
    FilledButton(onPressed:busy?null:submit,child:Padding(padding:const EdgeInsets.all(13),child:Text(busy?'Please wait...':register?'Register':'Log in'))),
    TextButton(onPressed:busy?null:()=>setState(()=>register=!register),child:Text(register?'Already registered? Log in':'New resident? Register')),
    const SizedBox(height:12),const Text('Juristic accounts are created by the system administrator.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.black54)),
  ])))))));
}

