import 'package:codelessly_sdk/codelessly_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'transform_gesture_test.dart' as support;
void main(){
 testWidgets('bound pose feedback settles double tap and reset',(tester)async{
  final b=await support.board(tester,{'target':'content','minScale':1,'maxScale':5,'doubleTapScale':2.5,'scaleVariable':'zoom','xVariable':'px','yVariable':'py'},variables:[support.v('zoom',1),support.v('px',0),support.v('py',0)],bind:{'transformGesture.scale':r'${zoom}','transformGesture.x':r'${px}','transformGesture.y':r'${py}'});
  await tester.tapAt(const Offset(200,200));await tester.pump(const Duration(milliseconds:50));await tester.tapAt(const Offset(200,200));
  for(var i=0;i<180;i++)await tester.pump(const Duration(milliseconds:16));
  expect(b['zoom'],closeTo(2.5,.001));
  setVariableIn(b.scope,'zoom',1);setVariableIn(b.scope,'px',0);setVariableIn(b.scope,'py',0);
  for(var i=0;i<180;i++)await tester.pump(const Duration(milliseconds:16));
  expect(b['zoom'],1);expect(b.pose.scale,closeTo(1,.001));expect(b['px'],0);expect(b['py'],0);
 });
}
