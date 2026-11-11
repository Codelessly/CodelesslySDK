import 'package:codelessly_sdk_v2/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 for(final ranges in [[{'start':6,'end':12,'style':{'color':'#FF7056D8'}}],[{'start':2,'end':8,'style':{'fontWeight':700}},{'start':5,'end':10,'style':{'color':'#FF7056D8'}}]]){
  testWidgets('partial and overlapping text runs preserve every character: $ranges',(tester)async{
   final tree=NodeTree(DocumentSource(LayoutDocument.fromJson({'roots':['t'],'nodes':{'t':{'type':'text','layout':{'width':300,'height':60},'props':{'text':'hello cheers!','style':{'fontSize':24},'runs':ranges}}}})));
   addTearDown(tree.dispose);
   await tester.pumpWidget(MaterialApp(home:NodeView(tree:tree,rootId:'t')));
   final paragraphs=<RenderParagraph>[];
   void visit(RenderObject o){if(o is RenderParagraph)paragraphs.add(o);o.visitChildren(visit);}
   visit(tester.renderObject(find.byType(NodeView)));
   expect(paragraphs.single.text.toPlainText(),'hello cheers!');
  });
 }
}
