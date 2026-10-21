import { validateAuthors, validatePost } from './schema';
import { SeedAuthorRecord, SeedPostRecord } from './types';

const AUTHOR: SeedAuthorRecord = {
  slug: 'laozhang',
  nickname: '老张不加班',
  bio: '换过七台手机，最后只用两台。',
  gender: 1,
  circles: ['手机数码'],
  avatarColor: '#2F3A45',
};

const longBody = '壳这东西，薄一点就像没戴，代价是摔一次就心疼。我前后换了三次，'
  + '第一次是透明硅胶，两个月发黄。第二次是硬壳，按键按下去像隔着一层铁皮。'
  + '第三次是原厂那种超薄的，边角不割手，指纹也少，就是价格不太友好。';
// 130 字左右，落在测评体裁的下限之上
const BODY = `${longBody}${longBody.slice(0, 30)}`;

function basePost(): SeedPostRecord {
  return {
    id: 'shuma-0001',
    author: 'laozhang',
    genre: 'review',
    title: '换了三次手机壳，最后留下的还是原厂那个',
    content: BODY,
    tags: ['手机数码'],
    tier: 'solid',
    ageHours: 40,
    insight: '薄和防摔只能挑一个，先想清楚自己更怕哪件事。',
    structured: {
      pros: '薄，按键手感接近裸机，边角不割手。',
      cons: '价格贵，掉地上基本不缓冲。',
      rating: 4.2,
      targetAudience: '不喜欢厚重手感的人',
    },
    comments: [
      { author: 'laozhang', text: '补充一句，原厂壳的按键是独立的，不连体。', offsetMinutes: 30 },
    ],
  };
}

function run(post: SeedPostRecord) {
  const authors = new Map([[AUTHOR.slug, AUTHOR]]);
  return validatePost(post, '手机数码', 'shuma.json', authors);
}

describe('validatePost', () => {
  it('合法内容零错误', () => {
    expect(run(basePost())).toHaveLength(0);
  });

  it('缺一句结论会报错', () => {
    const post = basePost();
    delete post.insight;
    expect(run(post).some((issue) => issue.field === 'insight')).toBe(true);
  });

  it('首标签不是本圈会报错', () => {
    const post = basePost();
    post.tags = ['家电选购'];
    expect(run(post).some((issue) => issue.field === 'tags[0]')).toBe(true);
  });

  it('标签不在 23 个圈子里会报错', () => {
    const post = basePost();
    post.tags = ['手机数码', '数码选购'];
    expect(run(post).some((issue) => issue.field === 'tags[1]')).toBe(true);
  });

  it('避坑体裁不能用数字块', () => {
    const post = basePost();
    post.genre = 'pitfall';
    post.structured = { pitfallExperience: '被加价两千', correctApproach: '先签闭口合同' };
    post.blocks = [{ type: 'metric', title: '损失', value: '2000', unit: '元' }];
    expect(run(post).some((issue) => issue.message.includes('不支持 metric'))).toBe(true);
  });

  it('推荐指数越界会报错', () => {
    const post = basePost();
    post.structured = { ...post.structured, rating: 6 };
    expect(run(post).some((issue) => issue.field === 'structured.rating')).toBe(true);
  });

  it('评论时间偏移超过帖子年龄会报错', () => {
    const post = basePost();
    post.comments = [{ author: 'laozhang', text: '这条评论来自未来', offsetMinutes: 40 * 60 + 1 }];
    expect(run(post).some((issue) => issue.field === 'comments[0].offsetMinutes')).toBe(true);
  });

  it('分享体裁带结构化字段会报错', () => {
    const post = basePost();
    post.genre = 'share';
    expect(run(post).some((issue) => issue.field === 'structured')).toBe(true);
  });

  it('错误是收集式的，一次给全', () => {
    const post = basePost();
    post.title = '短';
    post.tags = ['家电选购'];
    delete post.insight;
    const issues = run(post);
    expect(issues.length).toBeGreaterThanOrEqual(3);
  });

  it('photoCount 合法时不报错', () => {
    const post = basePost();
    post.photoCount = 1;
    expect(run(post).filter((issue) => issue.field === 'photoCount')).toHaveLength(0);
  });

  it('photoCount 非法值报错', () => {
    for (const bad of [0, 1.5, 10]) {
      const post = basePost();
      post.photoCount = bad;
      expect(run(post).some((issue) => issue.field === 'photoCount')).toBe(true);
    }
  });
});

describe('validateAuthors', () => {
  it('正常作者通过', () => {
    expect(validateAuthors([AUTHOR], 'authors.json')).toHaveLength(0);
  });

  it('昵称重复会报错', () => {
    const issues = validateAuthors([AUTHOR, { ...AUTHOR, slug: 'laowang' }], 'authors.json');
    expect(issues.some((issue) => issue.message.includes('昵称重复'))).toBe(true);
  });
});
