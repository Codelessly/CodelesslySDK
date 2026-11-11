import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'actions/wiring_test.dart' show show, v;

Map<String,Json> nodes()=>{
 'col':{'type':'column','layout':{'width':200,'height':100},'props':{'scrollable':true,'crossAxisAlignment':'start'},'children':['top','bottom']},
 'top':{'type':'box','layout':{'width':200,'height':200},'decoration':{'fills':[{'color':'#FF00FF00'}]}},
 'bottom':{'type':'box','layout':{'width':200,'height':200},'decoration':{'fills':[{'color':'#FF0000FF'}]},'actions':[{'trigger':{'type':'click'},'actions':[{'type':'setVariable','variable':'taps','op':'add','value':'1'}]}]},
};
RenderDesignScroll viewport(NodeTree tree){RenderDesignScroll? found;void visit(RenderObject o){if(o is RenderDesignScroll)found??=o;o.visitChildren(visit);}visit(tree.boxOf('col')!);return found!;}
void main(){
 testWidgets('running columns scroll by wheel and drag; content hit tests at its offset',(tester)async{
  final s=await show(tester,nodes(),variables:[v('taps',0,VariableType.integer)]);
  final scroll=viewport(s.tree);expect(scroll.interactive,true);expect(scroll.maxScrollExtent,300);
  await tester.sendEventToBinding(const PointerScrollEvent(position:Offset(50,50),scrollDelta:Offset(0,150)));await tester.pump();expect(scroll.pixels,150);
  await tester.tapAt(const Offset(50,80));await tester.pump();expect(s['taps'],1);
  await tester.dragFrom(const Offset(50,70),const Offset(0,-40));await tester.pump();expect(scroll.pixels,greaterThan(150));await tester.pumpAndSettle();
  scroll.jumpTo(999);await tester.pump();expect(scroll.pixels,300);
 });
 testWidgets('design view stays at rest and does not consume wheel',(tester)async{
  final s=await show(tester,nodes(),interactive:false);final scroll=viewport(s.tree);expect(scroll.interactive,false);
  await tester.sendEventToBinding(const PointerScrollEvent(position:Offset(50,50),scrollDelta:Offset(0,100)));await tester.pump();expect(scroll.pixels,0);
 });
 testWidgets('scrollTo reveals targets inside render-tree viewports',(tester)async{
  final s=await show(tester,nodes());final scroll=viewport(s.tree);
  final action=Node.fromJson({'type':'box','actions':[{'trigger':{'type':'click'},'actions':[{'type':'scrollTo','node':'bottom','alignment':1,'durationMs':0}]}]},id:'action')!;
  await const CodelesslyActions().run(action,'click',s.context);await tester.pump();
  expect(scroll.pixels,300);
 });
 testWidgets('programmatic animation clamps requested offsets',(tester)async{
  final s=await show(tester,nodes());final scroll=viewport(s.tree);
  final done=scroll.animateTo(250,duration:const Duration(milliseconds:100));await tester.pump();await tester.pump(const Duration(milliseconds:100));await done;expect(scroll.pixels,250);
  scroll.jumpTo(-20);await tester.pump();expect(scroll.pixels,0);
 });
}
