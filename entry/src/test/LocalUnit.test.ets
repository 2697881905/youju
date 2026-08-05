import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PublishDraft } from '../main/ets/utils/publishDraft';
import { publishFlowStore } from '../main/ets/utils/publishFlowStore';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('assertContain', 0, () => {
      // Defines a test case. This API supports three parameters: test case name, filter parameter, and test case function.
      let a = 'abc';
      let b = 'b';
      // Defines a variety of assertion methods, which are used to declare expected boolean conditions.
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('keeps publish preview state in the process-only flow store', 0, () => {
      const draft: PublishDraft = {
        title: '测试草稿',
        content: '用于验证预览状态不会落入临时 AppStorage。',
        genre: 'review',
        tags: ['数码选购'],
        structuredData: {},
        images: ['https://example.com/cover.jpg'],
      };
      publishFlowStore.startNew('photo');
      publishFlowStore.beginPreview(draft, 'draft_1');
      publishFlowStore.setActiveDraftId('draft_2');

      const preview = publishFlowStore.getSession();
      expect(preview.intent).assertEqual('sync');
      expect(preview.activeDraftId).assertEqual('draft_2');
      expect(preview.previewDraft?.images[0]).assertEqual('https://example.com/cover.jpg');

      publishFlowStore.completePublish();
      const finished = publishFlowStore.getSession();
      expect(finished.intent).assertEqual('reset');
      expect(finished.completedDraftId).assertEqual('draft_2');
      expect(finished.previewDraft).assertNull();
    });
  });
}
