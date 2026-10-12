// 结构化协议 V3（证据链 / 数值类型）客户端侧回归。
// 这一层是纯函数，不碰 UI、不碰网络，所以能在真机测试模块里直接断言。
// 口径必须与 backend/src/utils/structuredDocument.ts 一致：前端放过的提交
// 若被后端按「超长/未知字段」拒绝，作者会在发布最后一步才看见错误。
import { describe, it, expect } from '@ohos/hypium';
import {
  StructuredBlock,
  StructuredDocument,
  StructuredEvidence,
  STRUCTURED_SCHEMA_VERSION,
} from '../../../main/ets/models/types';
import {
  MAX_EVIDENCE_NOTE,
  MAX_EVIDENCE_PER_BLOCK,
  MAX_EVIDENCE_SOURCE_REF,
  addStructuredEvidence,
  cloneStructuredBlock,
  cloneStructuredDocument,
  collectStructuredDocument,
  createStructuredBlock,
  emptyStructuredDocument,
  evidenceOf,
  parseStructuredMetricNumber,
  removeStructuredEvidence,
  structuredEvidenceCount,
  withStructuredBlockText,
  withStructuredEvidenceNote,
  withStructuredEvidenceRef,
  withStructuredMetricKind,
} from '../../../main/ets/utils/structuredDocument';

function repeatedChar(ch: string, times: number): string {
  let out: string = '';
  for (let i = 0; i < times; i++) {
    out += ch;
  }
  return out;
}

// 单块文档：块 id 固定，断言里直接引用
function singleBlockDoc(type: 'metric' | 'insight', value: string): StructuredDocument {
  const document: StructuredDocument = emptyStructuredDocument();
  const block: StructuredBlock = createStructuredBlock(type);
  block.value = value;
  document.blocks = [block];
  document.primaryBlockId = block.id;
  return document;
}

export default function structuredDocumentTest(): void {
  describe('StructuredDocumentV3Test', () => {

    // —— 版本与克隆 ——

    it('emptyDocument_stampsCurrentVersion', 0, () => {
      expect(emptyStructuredDocument().schemaVersion).assertEqual(STRUCTURED_SCHEMA_VERSION);
    });

    it('cloneDocument_keepsSourceVersion', 0, () => {
      const v2: StructuredDocument = emptyStructuredDocument();
      v2.schemaVersion = 2;
      expect(cloneStructuredDocument(v2).schemaVersion).assertEqual(2);
    });

    it('cloneBlock_carriesV3Fields', 0, () => {
      const source: StructuredBlock = createStructuredBlock('insight');
      source.value = '实测一周';
      source.kind = null;
      source.numberValue = 12;
      const withEvidence: StructuredDocument = emptyStructuredDocument();
      withEvidence.blocks = [source];
      withEvidence.primaryBlockId = source.id;
      const filled: StructuredDocument = addStructuredEvidence(withEvidence, source.id,
        'source', 'https://example.com/a', '说明书第 3 页');
      const clone: StructuredBlock = cloneStructuredBlock(filled.blocks[0]);
      expect(structuredEvidenceCount(clone)).assertEqual(1);
      expect(clone.numberValue).assertEqual(12);
      expect(evidenceOf(clone)[0].note).assertEqual('说明书第 3 页');
    });

    it('cloneBlock_deepCopiesEvidence', 0, () => {
      const source: StructuredBlock = createStructuredBlock('insight');
      source.value = 'x';
      const doc: StructuredDocument = emptyStructuredDocument();
      doc.blocks = [source];
      doc.primaryBlockId = source.id;
      const filled: StructuredDocument = addStructuredEvidence(doc, source.id, 'source', 'https://a', '原件');
      const clone: StructuredBlock = cloneStructuredBlock(filled.blocks[0]);
      const changed: StructuredDocument = withStructuredEvidenceNote(filled, source.id, 0, '改过的');
      // 改新文档不该回头动到克隆前的那份；两者互不共享条目
      expect(evidenceOf(changed.blocks[0])[0].note).assertEqual('改过的');
      expect(structuredEvidenceCount(clone)).assertEqual(1);
    });

    // —— 证据增删改 ——

    it('addEvidence_capsAtMaxPerBlock', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '实测一周');
      const blockId: string = doc.blocks[0].id;
      for (let i = 0; i < 10; i++) {
        doc = addStructuredEvidence(doc, blockId, 'source', 'https://src/' + String(i), '依据');
      }
      expect(structuredEvidenceCount(doc.blocks[0])).assertEqual(MAX_EVIDENCE_PER_BLOCK);
      doc = addStructuredEvidence(doc, blockId, 'source', 'https://over-limit', '还是依据');
      expect(structuredEvidenceCount(doc.blocks[0])).assertEqual(MAX_EVIDENCE_PER_BLOCK);
    });

    it('addEvidence_trimsAndCapsNote', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'source', '  https://trim.me  ',
        repeatedChar('字', MAX_EVIDENCE_NOTE + 40));
      const item: StructuredEvidence = evidenceOf(doc.blocks[0])[0];
      expect(item.ref).assertEqual('https://trim.me');
      expect(item.note.length).assertEqual(MAX_EVIDENCE_NOTE);
      const renamed: StructuredDocument = withStructuredEvidenceNote(doc, blockId, 0, '  改过的说明  ');
      expect(evidenceOf(renamed.blocks[0])[0].note).assertEqual('改过的说明');
    });

    it('evidenceEdit_ignoresOutOfRangeIndex', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'source', 'https://a', '原说明');
      const untouched: StructuredDocument = withStructuredEvidenceNote(doc, blockId, 9, '越界不改');
      expect(evidenceOf(untouched.blocks[0])[0].note).assertEqual('原说明');
      const removed: StructuredDocument = removeStructuredEvidence(doc, blockId, 9);
      expect(structuredEvidenceCount(removed.blocks[0])).assertEqual(1);
    });

    it('evidenceEdit_ignoresUnknownBlock', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      doc = addStructuredEvidence(doc, doc.blocks[0].id, 'source', 'https://a', '一条');
      const after: StructuredDocument = addStructuredEvidence(doc, 'no-such-block', 'source', 'https://b', '第二条');
      expect(structuredEvidenceCount(after.blocks[0])).assertEqual(1);
    });

    it('sourceEvidence_refCapsAtMaxLen', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'source', 'https://a', 'n');
      const long: StructuredDocument = withStructuredEvidenceRef(doc, blockId, 0,
        'h' + repeatedChar('x', MAX_EVIDENCE_SOURCE_REF));
      expect(evidenceOf(long.blocks[0])[0].ref.length).assertEqual(MAX_EVIDENCE_SOURCE_REF);
    });

    // 图片证据的 ref 是上传引用，不是可编辑文本：放开手改等于让观看者客户端去 GET 外链。
    it('imageEvidence_refIsNotEditable', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'image', 'cos://posts/a.jpg', '实测图');
      const tampered: StructuredDocument = withStructuredEvidenceRef(doc, blockId, 0, 'https://evil.example/x');
      expect(evidenceOf(tampered.blocks[0])[0].ref).assertEqual('cos://posts/a.jpg');
    });

    it('removeEvidence_drainsAndSurvivesEmpty', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', 'x');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'source', 'https://a', 'n');
      doc = removeStructuredEvidence(doc, blockId, 0);
      expect(structuredEvidenceCount(doc.blocks[0])).assertEqual(0);
      doc = removeStructuredEvidence(doc, blockId, 0);
      expect(structuredEvidenceCount(doc.blocks[0])).assertEqual(0);
    });

    // —— 数字块 kind / numberValue ——

    it('metricKind_writesNumberValueTogether', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('metric', '到手 4.8 分');
      doc = withStructuredMetricKind(doc, doc.blocks[0].id, 'score');
      expect(doc.blocks[0].kind).assertEqual('score');
      expect(doc.blocks[0].numberValue).assertEqual(4.8);
    });

    it('metricKind_refusesNonMetricBlock', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '结论');
      const blockId: string = doc.blocks[0].id;
      doc = withStructuredMetricKind(doc, blockId, 'count');
      // 后端只允许 metric 带 kind/numberValue，非 metric 直接不改，保住这条不变量
      expect(doc.blocks[0].kind === undefined || doc.blocks[0].kind === null).assertTrue();
    });

    it('parseMetricNumber_handlesRealAuthorText', 0, () => {
      expect(parseStructuredMetricNumber('¥3,200')).assertEqual(3200);
      expect(parseStructuredMetricNumber('很好用')).assertEqual(0);
      expect(parseStructuredMetricNumber('降了 -12.5%')).assertEqual(-12.5);
    });

    // —— 发布前收敛 collectStructuredDocument ——

    it('collect_keepsEvidenceAndSearchable', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '有依据的结论');
      const blockId: string = doc.blocks[0].id;
      doc = addStructuredEvidence(doc, blockId, 'source', 'https://evidence', '出处名');
      doc = addStructuredEvidence(doc, blockId, 'image', 'cos://posts/p.jpg', '');
      const collected: StructuredDocument = collectStructuredDocument(doc);
      expect(collected.schemaVersion).assertEqual(STRUCTURED_SCHEMA_VERSION);
      expect(structuredEvidenceCount(collected.blocks[0])).assertEqual(2);
    });

    it('collect_prunesEmptyBlocksAndPrimary', 0, () => {
      const collected: StructuredDocument = collectStructuredDocument(singleBlockDoc('insight', '   '));
      expect(collected.blocks.length).assertEqual(0);
      expect(collected.primaryBlockId).assertEqual('');
    });

    it('collect_bumpsV2DraftOnlyWhenV3Used', 0, () => {
      let plain: StructuredDocument = singleBlockDoc('insight', '没证据的普通结论');
      plain.schemaVersion = 2;
      expect(collectStructuredDocument(plain).schemaVersion).assertEqual(2);

      let withEvidence: StructuredDocument = singleBlockDoc('insight', '来自 V2 草稿');
      withEvidence.schemaVersion = 2;
      withEvidence = addStructuredEvidence(withEvidence, withEvidence.blocks[0].id, 'source', 'https://x', 'n');
      expect(collectStructuredDocument(withEvidence).schemaVersion).assertEqual(3);
    });

    // 回归：作者点了「出处」但一个字没填，这条半成品不能进提交体，
    // 否则后端按「证据内容不能为空」在发布最后一步挡回来。
    it('collect_dropsHalfFilledEvidence', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '结论');
      doc = addStructuredEvidence(doc, doc.blocks[0].id, 'source', '', '');
      const collected: StructuredDocument = collectStructuredDocument(doc);
      expect(evidenceOf(collected.blocks[0]).length).assertEqual(0);
      expect(JSON.stringify(collected.blocks[0]).includes('"evidence"')).assertFalse();
    });

    it('collect_emptyEvidenceDoesNotBumpV2', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '结论');
      doc.schemaVersion = 2;
      doc = addStructuredEvidence(doc, doc.blocks[0].id, 'source', '', '');
      expect(collectStructuredDocument(doc).schemaVersion).assertEqual(2);
    });

    // —— 编辑路径不丢证据 ——

    it('editText_keepsEvidence', 0, () => {
      let doc: StructuredDocument = singleBlockDoc('insight', '原结论');
      doc = addStructuredEvidence(doc, doc.blocks[0].id, 'source', 'https://keep', '要留住');
      doc = withStructuredBlockText(doc, doc.blocks[0].id, 'value', '改过的结论');
      expect(structuredEvidenceCount(doc.blocks[0])).assertEqual(1);
      expect(doc.blocks[0].value).assertEqual('改过的结论');
    });
  });
}
