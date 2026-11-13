import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
class Validator implements ScriptRunner {
 Object? value; Completer<void>? gate;Json? args;
 Validator(this.value);
 @override Future<ScriptRunResult> run(ScriptDef script,{Json args=const {},List<ScriptDef> scripts=const [],ScriptHost? host})async{this.args=args;await gate?.future;return ScriptRunResult(value:value);}
}
class FormHarness {
 final scope=VariableScope([const Variable(name:'answers',type:VariableType.map,value:{'email':'ada@example.test','hidden':'private'}),const Variable(name:'responses',type:VariableType.list,value:[]),const Variable(name:'result',type:VariableType.map,value:{}),const Variable(name:'success',type:VariableType.boolean,value:false),const Variable(name:'errors',type:VariableType.map,value:{})]);
 late RuntimeActionContext context;
 final failures=<Object>[];
 FormHarness({ScriptRunner? runner}){context=RuntimeActionContext(scope:scope,services:Services(scripts:runner),scripts:[const ScriptDef(id:'validate',name:'validate')],onError:(e,s,a)=>failures.add(e));}
 Future<void> submit(Json action)=>const CodelesslyActions().run(Node.fromJson({'type':'box','actions':[{'trigger':{'type':'click'},'actions':[{'type':'submitForm','service':'local','payload':r'${answers}','responseVariable':'responses','resultVariable':'result','onSuccess':[{'type':'setVariable','variable':'success','value':'true'}],'onError':[{'type':'setVariable','variable':'errors','value':r'${result.errors}'}],...action}]}]},id:'button')!,'click',context);
}
void main(){
 test('a form submission stores its values and runs its success actions',()async{final h=FormHarness();await h.submit({});expect(h.scope.read('responses'),[{'email':'ada@example.test','hidden':'private'}]);expect(h.scope.read('success'),true);expect((h.scope.read('result') as Map)['ok'],true);expect(h.failures,isEmpty);});
 test('a validator can change the values before they are stored',()async{final v=Validator({'valid':true,'payload':{'email':'ada@example.test'}})..gate=Completer<void>();final h=FormHarness(runner:v);final pending=h.submit({'validationScript':'validate','validationArguments':{'data':r'${answers}'}});await Future<void>.delayed(Duration.zero);expect(h.scope.read('responses'),isEmpty);v.gate!.complete();await pending;expect(v.args!['data'],h.scope.read('answers'));expect(h.scope.read('responses'),[{'email':'ada@example.test'}]);});
 test('a submission its validator rejects is not stored and runs no success actions',()async{final h=FormHarness(runner:Validator({'valid':false,'errors':{'age':'Must be 18+'}}));await h.submit({'validationScript':'validate'});expect(h.scope.read('responses'),isEmpty);expect(h.scope.read('success'),false);expect(h.scope.read('errors'),{'age':'Must be 18+'});expect((h.scope.read('result') as Map)['error'],containsPair('code','validation_failed'));});
 test('a submission with nowhere to go, or with values that are not a record, fails and changes nothing',()async{final h=FormHarness();await h.submit({'responseVariable':'missing'});expect(h.scope.read('responses'),isEmpty);expect((h.scope.read('result') as Map)['error'],containsPair('code','invalid_response_variable'));await h.submit({'payload':'42'});expect(h.scope.read('responses'),isEmpty);expect((h.scope.read('result') as Map)['ok'],false);});

 group('a submission saved for the removed newsletter services',(){
  // A layout saved before the built-in Mailchimp service was removed.
  const legacy={'type':'submitForm','service':'mailchimp','emailField':'email','apiKey':'secret-us1','dataCenter':'us1','listId':'list','firstNameField':'first'};
  Future<List<Object>> noNetwork(Future<void> Function() body)async{
   final requests=<Object>[];
   await HttpOverrides.runZoned(()=>http.runWithClient(body,()=>MockClient((r)async{requests.add(r.url);return http.Response('',200);})),
    createHttpClient:(_){requests.add('dart:io HttpClient');throw StateError('no network in this test');});
   return requests;
  }
  Future<(FormHarness,List<Object>)> run(Json action,{bool callbacks=true})async{
   final h=FormHarness();
   final requests=await noNetwork(()=>callbacks?h.submit(action):const CodelesslyActions().run(Node.fromJson({'type':'box','actions':[{'trigger':{'type':'click'},'actions':[action,{'type':'setVariable','variable':'success','value':'true'}]}]},id:'button')!,'click',h.context));
   return (h,requests);
  }
  test('without callbacks is reported as an action error, stops the chain and sends nothing',()async{
   final (h,requests)=await run(legacy,callbacks:false);
   expect(requests,isEmpty);
   expect(h.failures,hasLength(1));
   expect(h.failures.single,isA<ActionFailed>().having((e)=>e.action,'action','submitForm'));
   expect('${h.failures.single}',contains('no longer supported'));
   expect(h.scope.read('success'),false);
  });
  test('with callbacks runs its error actions and stores or sends nothing',()async{
   final (h,requests)=await run({...legacy});
   expect(requests,isEmpty);
   expect(h.failures,isEmpty);
   expect(h.scope.read('responses'),isEmpty);
   expect(h.scope.read('success'),false);
   expect((h.scope.read('result') as Map)['error'],containsPair('code','unsupported_service'));
  });
 });
}
