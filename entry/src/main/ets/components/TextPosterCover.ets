// 文字海报封面：无图纯文本帖在列表里的封面。
//
// 背景：首页/搜索的帖子发布时会上传海报并落库为 coverImage（图片 URL）；而**草稿**只存在本地，
// 没有这个 URL —— 预览页（PublishPreviewPage）能显示文字海报是因为它调用
// renderPosterPixelMap 现渲染，草稿箱卡片过去直接走 PostCardMedia → 只认图片 URL → 无封面。
// 本组件把「现渲染海报」这一步复用到列表卡片：与发布产物同源（同一个 renderPosterPixelMap），
// 只是取缩略图倍率（POSTER_THUMB_SCALE），避免列表里持有发布级大图。
//
// 比例：海报 1080×1440 → 0.75，与 LayoutTokens.cardMediaAspectRatio 相同，卡片高度与图文卡一致。
import { image } from '@kit.ImageKit';
import { renderPosterPixelMap } from '../utils/poster/posterRender';
import { POSTER_THUMB_SCALE, TEXT_POSTER_ASPECT_RATIO } from '../utils/poster/posterTokens';
import { ColorTokens } from '../design/tokens/color';
import { RadiusTokens } from '../design/tokens/radius';

@Component
export struct TextPosterCover {
  @Prop title: string = '';
  @Prop content: string = '';
  // 草稿持久化的样式 key（draft.textPosterStyle）；非法/缺失由 resolveTextPosterStyle 兜底
  @Prop styleKey: string = '';
  @Prop compact: boolean = false;
  // id 透传（一镜到底定位用；空串=不挂）
  @Prop mediaId: string = '';
  @State poster: image.PixelMap | undefined = undefined;

  aboutToAppear(): void {
    try {
      this.poster = renderPosterPixelMap(this.title, this.content, this.styleKey, POSTER_THUMB_SCALE);
    } catch (e) {
      // 渲染失败退化为纯色占位，不阻断列表
      this.poster = undefined;
    }
  }

  aboutToDisappear(): void {
    // 列表滚出/页面销毁时释放，避免多张海报 PixelMap 常驻
    const map: image.PixelMap | undefined = this.poster;
    if (map !== undefined) {
      map.release().catch((): void => {});
      this.poster = undefined;
    }
  }

  build() {
    Stack() {
      if (this.poster !== undefined) {
        Image(this.poster)
          .id(this.mediaId)
          .width('100%')
          .aspectRatio(TEXT_POSTER_ASPECT_RATIO)
          .objectFit(ImageFit.Cover)
          .draggable(false)
      }
    }
    .width('100%')
    .aspectRatio(TEXT_POSTER_ASPECT_RATIO)
    // 未渲染完成 / 渲染失败时的占位底色（与 PostCardMedia 的封面兜底同色）
    .backgroundColor(ColorTokens.sunken)
    .borderRadius({
      topLeft: this.compact ? RadiusTokens.xs : RadiusTokens.lg,
      topRight: this.compact ? RadiusTokens.xs : RadiusTokens.lg,
      bottomLeft: 0,
      bottomRight: 0,
    })
    .clip(true)
  }
}
