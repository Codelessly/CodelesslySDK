import 'package:codelessly_sdk/codelessly_sdk.dart';
// ignore: implementation_imports
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared computed script data refreshes lists after an app variable changes', (tester) async {
    final app = VariableScope(const [
      Variable(name:'revision',type:VariableType.integer,value:0),
      Variable(name:'view',type:VariableType.map,formula:'script.projector(revision)'),
    ]);
    final scripts = ScriptsScope(
      scripts:[ScriptDef.fromJson({'id':'projector','name':'projector','source':'return null','params':[{'name':'revision'}]})!],
      runner:FunctionScriptRunner({'projector':(args,_) async => {'history':args['revision']==0?<String>[]:['Week one']}}),
      parent:app,
    );
    final screen=VariableScope(const [],parent:scripts);scripts.reader=screen;
    final doc=LayoutDocument.fromJson({'roots':['list'],'nodes':{
      'list':{'type':'listView','children':['label'],'layout':{'width':400,'height':400},'bind':{'data':r'${view.history}'}},
      'label':{'type':'text','layout':{'width':400,'height':40},'props':{'text':r'${item}'}},
    }});
    final tree=NodeTree(DocumentSource(doc),binder:NodeBinder(scope:screen));
    addTearDown((){tree.dispose();screen.dispose();scripts.dispose();app.dispose();});
    await tester.pumpWidget(MaterialApp(home:NodeView(tree:tree,rootId:'list',interactive:true)));
    await tester.pumpAndSettle();
    app.set('revision',1);
    await tester.pumpAndSettle();
    expect(screen.read('view'),{'history':['Week one']});
    final texts=<String>[];
    void visit(RenderObject object){if(object is RenderParagraph)texts.add(object.text.toPlainText());object.visitChildren(visit);}
    visit(tester.renderObject(find.byType(NodeView)));
    expect(texts,contains('Week one')); 
    expect(tester.takeException(),isNull);
  });
}
