import { isAllowedUpload } from './upload';

describe('isAllowedUpload', () => {
  it('只允许既定图片类型写入图片目录', () => {
    expect(isAllowedUpload('image/jpeg', 'posts')).toBe(true);
    expect(isAllowedUpload('image/webp', 'avatars')).toBe(true);
    expect(isAllowedUpload('image/svg+xml', 'posts')).toBe(false);
    expect(isAllowedUpload('text/html', 'backgrounds')).toBe(false);
  });

  it('video 目录只允许 MP4，图片目录拒绝视频', () => {
    expect(isAllowedUpload('video/mp4', 'video')).toBe(true);
    expect(isAllowedUpload('video/quicktime', 'video')).toBe(false);
    expect(isAllowedUpload('video/mp4', 'posts')).toBe(false);
  });
});
