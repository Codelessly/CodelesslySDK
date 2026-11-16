#!/usr/bin/env python3
"""Tests of the toolkit's own code (tool/cli), without Flutter: python3 tool/cli/test_cli.py

The render command itself is tested by test/tool/*_test.dart; these cover what tool/cli adds on top: trees
flattened, the reference looked up, outlines built from layout dumps, sheets, the states manifest's steps and the
MCP server's protocol.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import docs  # noqa: E402
import flatten  # noqa: E402
import outline  # noqa: E402
import states  # noqa: E402


class FlattenTest(unittest.TestCase):
    def test_a_tree_that_is_not_a_canvas_goes_in_a_canvas_body(self):
        doc = flatten.flatten({'type': 'column', 'key': 'page', 'children': [
            {'type': 'text', 'key': 'title', 'props': {'text': 'A'}},
            {'type': 'text', 'props': {'text': 'B'}},
        ]}, size=(390, 844))
        self.assertEqual(doc['schema'], 3)
        self.assertEqual(doc['roots'], ['screen'])
        canvas = doc['nodes']['screen']
        self.assertEqual(canvas['slots'], {'body': 'page'})
        self.assertEqual(canvas['layout'], {'width': 390, 'height': 844})
        self.assertEqual(doc['nodes']['page']['children'], ['title', 'text'])
        self.assertEqual(list(doc['nodes'])[0], 'screen')  # canvases first

    def test_at_keys_become_ids_everywhere(self):
        doc = flatten.flatten({'type': 'column', 'children': [
            {'type': 'text', 'key': 'msg'},
            {'type': 'filledButton', 'key': 'msg', 'actions': [{'trigger': 'click', 'actions': [
                {'type': 'setValue', 'node': '@msg'}]}]},
        ]})
        ids = [k for k, v in doc['nodes'].items() if v['type'] != 'canvas' and v['type'] != 'column']
        self.assertEqual(ids, ['msg', 'msg1'])  # a repeated key gets a fresh id
        target = doc['nodes']['msg1']['actions'][0]['actions'][0]['node']
        self.assertEqual(target, 'msg1')  # "@msg" names the last node with that key

    def test_trees_per_breakpoint_are_one_screen(self):
        doc = flatten.flatten({'trees': {'mobile': {'type': 'column'}, 'desktop': {'type': 'row'}},
                               'variables': [{'name': 'n', 'type': 'integer', 'value': 0}]}, screen='home')
        self.assertEqual(doc['roots'], ['home_mobile', 'home_desktop'])
        self.assertEqual(doc['nodes']['home_desktop']['props'], {'screen': 'home', 'breakpoint': 'desktop'})
        self.assertEqual(doc['nodes']['home_desktop']['layout'], {'width': 1440, 'height': 900})
        self.assertEqual(doc['variables'], {'page_variables': [{'name': 'n', 'type': 'integer', 'value': 0}]})

    def test_a_document_with_nested_children_keeps_its_ids(self):
        doc = flatten.flatten({'schema': 3, 'roots': ['c'], 'nodes': {
            'c': {'type': 'canvas', 'slots': {'body': {'type': 'column', 'key': 'col', 'children': ['t']}}},
            't': {'type': 'text'},
        }})
        self.assertEqual(doc['nodes']['c']['slots'], {'body': 'col'})
        self.assertEqual(doc['nodes']['col']['children'], ['t'])
        self.assertIn('t', doc['nodes'])


class DocsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            cls.ref = docs.Reference(docs.find_reference(None))
        except SystemExit:
            raise unittest.SkipTest('no codelessly_api reference beside the SDK')

    def test_a_name_finds_its_section(self):
        file, anchor = self.ref.exact('row')
        body = '\n'.join(self.ref.section(file, anchor))
        self.assertIn('`row`', body)
        self.assertIn('mainAxisAlignment', body)

    def test_a_section_stops_at_the_next_heading_of_its_level(self):
        file, anchor = self.ref.exact('row')
        body = self.ref.section(file, anchor)
        self.assertFalse(any(l.startswith('### `column`') for l in body))

    def test_words_find_a_need(self):
        hits = self.ref.search(['sticky', 'header'])
        self.assertTrue(hits)
        self.assertIn('sticky', hits[0][4])


class OutlineTest(unittest.TestCase):
    def test_the_tree_boxes_texts_and_problems(self):
        with tempfile.TemporaryDirectory() as d:
            doc = {'schema': 3, 'roots': ['home'], 'nodes': {
                'home': {'type': 'canvas', 'slots': {'body': 'col'}},
                'col': {'type': 'column', 'children': ['a', 'b']},
                'a': {'type': 'text'}, 'b': {'type': 'box'}}}
            (Path(d) / 'doc.json').write_text(json.dumps(doc))
            out = Path(d) / 'out'
            out.mkdir()
            (out / 'home@390x844.png.layout.json').write_text(json.dumps([
                {'id': 'home', 'x': 0, 'y': 0, 'w': 390, 'h': 844},
                {'id': 'col', 'x': 0, 'y': 0, 'w': 390, 'h': 100},
                {'id': 'a', 'x': 0, 'y': 0, 'w': 100, 'h': 20, 'text': 'Hello'},
                {'id': 'b', 'x': 0, 'y': 20, 'w': 0, 'h': 0}]))
            (out / 'diagnostics.json').write_text(json.dumps({'diagnostics': [
                {'code': 'text_clipped', 'severity': 'warning', 'nodeId': 'a', 'screen': 'home', 'size': '390x844',
                 'message': 'clipped'}]}))
            types, parents = outline.load_documents([str(Path(d) / 'doc.json')])
            lines = outline.outline_capture(json.loads((out / 'home@390x844.png.layout.json').read_text()),
                                            types, parents, outline.capture_diagnostics(out, 'home@390x844'))
            self.assertTrue(lines[0].startswith('canvas home'))
            self.assertTrue(lines[1].startswith('  column col'))
            self.assertIn('text a', lines[2])
            self.assertIn('"Hello"', lines[2])
            self.assertEqual(lines[3].strip(), '! text_clipped: clipped')
            self.assertIn('(empty: draws nothing)', lines[4])
            self.assertTrue(lines[4].startswith('    box b'))


class StatesTest(unittest.TestCase):
    def test_steps_become_render_options(self):
        self.assertEqual(states.step_args([{'tap': 'go'}, {'unfocus': True}, ['--wait', '300'], {'set': 'n=1'}]),
                         ['--tap', 'go', '--unfocus', '--wait', '300', '--set', 'n=1'])


class SheetTest(unittest.TestCase):
    def test_one_row_per_state_narrowest_first(self):
        import sheet
        files = [Path(f'/x/home@{s}{l}.png') for s in ('1440x900', '390x844') for l in ('', '-saved')]
        rows = sheet.rows_of(files, None)
        self.assertEqual([[f.name for f in r] for r in rows],
                         [['home@390x844.png', 'home@1440x900.png'], ['home@390x844-saved.png', 'home@1440x900-saved.png']])


class McpTest(unittest.TestCase):
    def test_initialize_list_and_flatten(self):
        msgs = [
            {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}},
            {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
            {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
            {'jsonrpc': '2.0', 'id': 3, 'method': 'tools/call',
             'params': {'name': 'codelessly_flatten', 'arguments': {'tree': {'type': 'column'}}}},
            {'jsonrpc': '2.0', 'id': 4, 'method': 'nope'},
        ]
        with tempfile.TemporaryDirectory() as work:
            p = subprocess.run([sys.executable, str(HERE / 'mcp_server.py')], text=True, capture_output=True,
                               input=''.join(json.dumps(m) + '\n' for m in msgs), env={'CODELESSLY_MCP_WORK': work},
                               timeout=60)
        answers = {r['id']: r for r in map(json.loads, p.stdout.splitlines())}
        self.assertEqual(sorted(answers), [1, 2, 3, 4])  # the notification gets no answer
        self.assertEqual(answers[1]['result']['protocolVersion'], '2025-06-18')
        names = [t['name'] for t in answers[2]['result']['tools']]
        self.assertEqual(names, ['codelessly_docs', 'codelessly_validate', 'codelessly_render', 'codelessly_flatten',
                                 'codelessly_states'])
        doc = json.loads(answers[3]['result']['content'][0]['text'])
        self.assertEqual(doc['roots'], ['screen'])
        self.assertEqual(answers[4]['error']['code'], -32601)


if __name__ == '__main__':
    unittest.main(verbosity=1)
