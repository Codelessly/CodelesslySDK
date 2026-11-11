import 'package:codelessly_api/codelessly_api.dart' as api;
import 'package:codelessly_sdk/src/runtime/actions/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 testWidgets('modals retain localizations provided below the navigator',(tester) async {
  late NavigatorActionUi ui;
  await tester.pumpWidget(WidgetsApp(color:Colors.white, onGenerateRoute:(_)=>PageRouteBuilder(pageBuilder:(context,a,b)=>Localizations.override(context:context,delegates:const[DefaultMaterialLocalizations.delegate],child:Builder(builder:(source){ui=NavigatorActionUi(context:()=>source,modal:(_,_)=>const Material(child: SizedBox(width:200,height:100,child:TextField())));return const SizedBox();})))));
  ui.openModal(const api.OpenModalAction(to:'compose',barrierBlur:1,enterScale:.94));
  await tester.pumpAndSettle();
  expect(find.byType(TextField),findsOneWidget);
  expect(tester.takeException(),isNull);
 });
}
