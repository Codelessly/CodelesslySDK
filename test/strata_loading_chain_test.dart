import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' as support;
void main(){
 testWidgets('load chain survives the layout change caused by its own loading indicator',(tester) async {
  final s=await support.show(tester,{
   'col':{'type':'column','layout':{'width':200,'height':{'hug':100}},'children':['label','loading']},
   'label':{'type':'text','layout':{'width':200,'height':30},'props':{'text':'Specimen'},'actions':[support.reaction('load',[
    {'type':'setVariable','variable':'loading','value':'true'},
    {'type':'delay','ms':100},
    {'type':'setVariable','variable':'loading','value':'false'},
   ])]},
   'loading':{'type':'box','layout':{'width':200,'height':100},'bind':{'visible':r'${loading}'}},
  },variables:[support.v('loading',false,VariableType.boolean)]);
  await tester.pump();expect(s['loading'],true);
  await tester.pump(const Duration(milliseconds:200));await tester.pump();expect(s['loading'],false);
 });
}
