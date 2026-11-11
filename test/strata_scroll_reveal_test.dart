import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:codelessly_sdk/src/render/behaviours.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 testWidgets('scroll reveal holds its entrance pose until its clipped viewport becomes visible',(tester) async {
  final tree=NodeTree(DocumentSource(LayoutDocument.fromJson({'roots':['body'],'nodes':{
   'body':{'type':'column','layout':{'width':200,'height':120},'props':{'scrollable':true},'children':['lead','target']},
   'lead':{'type':'box','layout':{'width':200,'height':240}},
   'target':{'type':'box','layout':{'width':200,'height':120},'motion':{'enter':true,'enterFrom':{'translateY':30,'opacity':0},'duration':400,'revealOnScroll':true}},
  }})));
  addTearDown(tree.dispose);
  await tester.pumpWidget(MaterialApp(home:Align(alignment:Alignment.topLeft,child:NodeView(tree:tree,rootId:'body',interactive:true))));
  RenderMotion? motion;RenderDesignScroll? scroll;
  void visit(RenderObject o){if(o is RenderMotion)motion=o;if(o is RenderDesignScroll)scroll=o;o.visitChildren(visit);}
  visit(tree.boxOf('body')!);
  await tester.pump(const Duration(seconds:1));
  expect(motion!.effectiveTransform.getTranslation().y,30);
  scroll!.jumpBy(240);await tester.pump();await tester.pump();await tester.pump(const Duration(milliseconds:200));
  expect(motion!.effectiveTransform.getTranslation().y,inExclusiveRange(0,30));
  await tester.pump(const Duration(milliseconds:250));expect(motion!.effectiveTransform.getTranslation().y,closeTo(0,1e-6));
 });
}
