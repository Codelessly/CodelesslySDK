import 'dart:async';
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
 test('local submission snapshots arbitrary JSON and calls success',()async{final h=FormHarness();await h.submit({});expect(h.scope.read('responses'),[{'email':'ada@example.test','hidden':'private'}]);expect(h.scope.read('success'),true);expect((h.scope.read('result') as Map)['ok'],true);expect(h.failures,isEmpty);});
 test('awaited validator normalizes payload before insertion',()async{final v=Validator({'valid':true,'payload':{'email':'ada@example.test'}})..gate=Completer<void>();final h=FormHarness(runner:v);final pending=h.submit({'validationScript':'validate','validationArguments':{'data':r'${answers}'}});await Future<void>.delayed(Duration.zero);expect(h.scope.read('responses'),isEmpty);v.gate!.complete();await pending;expect(v.args!['data'],h.scope.read('answers'));expect(h.scope.read('responses'),[{'email':'ada@example.test'}]);});
 test('validation rejection never stores or runs success',()async{final h=FormHarness(runner:Validator({'valid':false,'errors':{'age':'Must be 18+'}}));await h.submit({'validationScript':'validate'});expect(h.scope.read('responses'),isEmpty);expect(h.scope.read('success'),false);expect(h.scope.read('errors'),{'age':'Must be 18+'});expect((h.scope.read('result') as Map)['error'],containsPair('code','validation_failed'));});
 test('malformed validator fails closed',()async{final h=FormHarness(runner:Validator({'valid':'yes'}));await h.submit({'validationScript':'validate'});expect(h.scope.read('responses'),isEmpty);expect((h.scope.read('result') as Map)['error'],containsPair('code','invalid_validation_result'));});
 test('missing destination and non-object payload fail without mutation',()async{final h=FormHarness();await h.submit({'responseVariable':'missing'});expect(h.scope.read('responses'),isEmpty);expect((h.scope.read('result') as Map)['error'],containsPair('code','invalid_response_variable'));await h.submit({'payload':'42'});expect(h.scope.read('responses'),isEmpty);expect((h.scope.read('result') as Map)['ok'],false);});
 test('prepend preserves the existing response order',()async{final h=FormHarness();await h.submit({'payload':r'${= {"id": "first"}}'});await h.submit({'payload':r'${= {"id": "second"}}','prepend':true});expect(h.scope.read('responses'),[{'id':'second'},{'id':'first'}]);});
}
