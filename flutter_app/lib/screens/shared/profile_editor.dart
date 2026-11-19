part of '../../main.dart';

class ProfileEditor extends StatefulWidget {
  final Map<String,dynamic> user;
  const ProfileEditor({super.key, required this.user});
  @override State<ProfileEditor> createState()=>_ProfileEditorState();
}
class _ProfileEditorState extends State<ProfileEditor> {
  final form=GlobalKey<FormState>();
  late final TextEditingController name=TextEditingController(text:'${widget.user['full_name']??''}');
  late final TextEditingController phone=TextEditingController(text:'${widget.user['phone']??''}');
  bool saving=false;
  @override void dispose(){name.dispose();phone.dispose();super.dispose();}
  Future<void> save() async {
    if(!form.currentState!.validate())return;
    setState(()=>saving=true);
    try {
      await Api.request('PUT','/me',{'full_name':name.text.trim(),'phone':phone.text.trim()});
      if(mounted){toast(context,'Profile updated');Navigator.pop(context,true);}
    }catch(e){if(mounted)toast(context,err(e));}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Edit profile')),
    body:Form(key:form,child:ListView(padding:const EdgeInsets.all(20),children:[
      TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full name'),validator:(v)=>v==null||v.trim().length<2?'Enter your name':null),
      const SizedBox(height:14),
      TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone number'),validator:(v)=>v==null||v.trim().length<6?'Enter a valid phone number':null),
      const SizedBox(height:20),
      FilledButton(onPressed:saving?null:save,child:Text(saving?'Saving...':'Save changes')),
    ])),
  );
}
