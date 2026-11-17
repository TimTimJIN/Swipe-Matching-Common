import 'dart:async';

import 'api.dart';
import 'config.dart';
import 'in_memory_server.dart';
import 'models.dart';

/// Fictional data for trying the platform without a server.
/// Every person and listing here is made up.
class DemoWorld {
  DemoWorld._(this.server, this.config, this.meId, this._simulator);

  final InMemoryServer server;
  final ServiceConfig config;
  final String meId;
  final StreamSubscription<MatchingEvent> _simulator;

  MatchingApi get api => server.clientFor(meId);

  Future<void> dispose() => _simulator.cancel();

  /// Person-to-person: a match needs mutual interest.
  /// Peers listed in `_hobbyLikesMe` have already shown interest in "me".
  factory DemoWorld.hobby({Duration peerDelay = const Duration(seconds: 1)}) {
    final server = InMemoryServer();
    final config = hobbyConfig;
    server.registerService(config);
    const meId = 'hobby_me';
    server.addMember(const Member(
        id: meId, serviceId: 'hobby', displayName: 'あなた（試用）'));
    server.addCard(const Candidate(
      id: 'card_hobby_me',
      serviceId: 'hobby',
      ownerId: meId,
      title: 'あなた（試用）',
      attributes: {'hobbies': ['散歩'], 'area': '東京', 'intro': '試用中の会員です。'},
    ));
    for (final (i, p) in _hobbyPeople.indexed) {
      final id = 'hobby_p$i';
      server.addMember(Member(id: id, serviceId: 'hobby', displayName: p.$1));
      server.addCard(Candidate(
        id: 'card_$id',
        serviceId: 'hobby',
        ownerId: id,
        title: p.$1,
        attributes: {'hobbies': p.$2, 'area': p.$3, 'intro': p.$4},
      ));
      if (_hobbyLikesMe.contains(i)) {
        server.seedDecision(id, 'card_hobby_me', SwipeIntent.positive);
      }
    }
    final sim = server.serverEvents.listen((event) {
      if (event case MatchCreated(:final match)) {
        final peer = match.otherParty(meId);
        if (peer == meId) return;
        Timer(peerDelay, () {
          server
              .clientFor(peer)
              .sendMessage(match.id, 'はじめまして！よろしくお願いします。',
                  'greet-${match.id}')
              .ignore();
        });
      }
    });
    return DemoWorld._(server, config, meId, sim);
  }

  /// Person-to-listing: an application matches once the owner approves.
  /// Owners of listings in `_workAutoApprove` approve after [ownerDelay].
  factory DemoWorld.work({Duration ownerDelay = const Duration(seconds: 1)}) {
    final server = InMemoryServer();
    final config = workConfig;
    server.registerService(config);
    const meId = 'work_me';
    server.addMember(const Member(
        id: meId, serviceId: 'work', displayName: 'あなた（試用）'));
    for (final (i, l) in _workListings.indexed) {
      final ownerId = 'work_owner$i';
      server.addMember(
          Member(id: ownerId, serviceId: 'work', displayName: l.$5));
      server.addCard(Candidate(
        id: 'listing_$i',
        serviceId: 'work',
        ownerId: ownerId,
        title: l.$1,
        attributes: {'field': l.$2, 'request': l.$3, 'terms': l.$4},
      ));
    }
    final sim = server.serverEvents.listen((event) {
      if (event case ApplicationReceived(:final application)) {
        final index = int.parse(application.listingId.split('_').last);
        if (!_workAutoApprove.contains(index)) return;
        Timer(ownerDelay, () {
          server
              .clientFor('work_owner$index')
              .approveApplication(application.id)
              .ignore();
        });
      }
    });
    return DemoWorld._(server, config, meId, sim);
  }
}

const hobbyConfig = ServiceConfig(
  serviceId: 'hobby',
  version: 1,
  displayName: '趣味仲間',
  targetKind: TargetKind.member,
  fields: [
    FieldSpec(key: 'hobbies', label: '趣味', kind: FieldKind.tags, required: true),
    FieldSpec(key: 'area', label: '地域', kind: FieldKind.shortText, required: true),
    FieldSpec(key: 'intro', label: '紹介文', kind: FieldKind.longText, maxLength: 500),
  ],
  intentLabels: IntentLabels(positive: '興味あり', negative: '見送り'),
  matchRule: MatchRuleId.mutualInterest,
  matchHint: 'お互いが「興味あり」を選ぶと成立します',
);

const workConfig = ServiceConfig(
  serviceId: 'work',
  version: 1,
  displayName: '仕事相談',
  targetKind: TargetKind.listing,
  fields: [
    FieldSpec(key: 'field', label: '分野', kind: FieldKind.tags, required: true),
    FieldSpec(key: 'request', label: '相談内容', kind: FieldKind.longText, required: true, maxLength: 800),
    FieldSpec(key: 'terms', label: '稼働条件', kind: FieldKind.shortText),
  ],
  intentLabels: IntentLabels(positive: '応募する', negative: '見送り'),
  matchRule: MatchRuleId.ownerApproval,
  matchHint: '応募を案件オーナーが承認すると成立します',
);

const _hobbyLikesMe = {0, 3, 7, 12};

const _hobbyPeople = <(String, List<String>, String, String)>[
  ('小川 はる', ['写真', '散歩'], '東京', '休日の朝に街を歩きながら、光や建物を撮る仲間を探しています。'),
  ('佐伯 あおい', ['登山'], '神奈川', '低山を中心に、月に一度くらい一緒に歩ける人を探しています。'),
  ('森田 けい', ['ボードゲーム'], '埼玉', '重めのゲームを週末にじっくり遊べる人を募集中です。'),
  ('高村 みお', ['料理', 'パン作り'], '東京', '季節の食材で作るパンを、一緒に試作しませんか。'),
  ('石井 そら', ['ランニング'], '千葉', '朝の5kmを続けられる仲間がほしいです。'),
  ('中野 りく', ['映画'], '東京', 'ミニシアター巡りと、観た後の感想会が好きです。'),
  ('川口 なつ', ['読書'], '神奈川', '月1冊の読書会を気軽に続けたいです。'),
  ('藤本 ゆい', ['カメラ', '旅行'], '静岡', '近場の小旅行で風景を撮っています。'),
  ('岡田 しん', ['釣り'], '千葉', '堤防釣りの初心者です。一緒に覚えましょう。'),
  ('山下 あや', ['ヨガ'], '東京', '公園での朝ヨガ仲間を探しています。'),
  ('松井 たく', ['自転車'], '埼玉', '川沿いを50kmほど走るのが定番です。'),
  ('田辺 さき', ['陶芸'], '東京', '教室帰りに作品を見せ合える友人がほしいです。'),
  ('野口 れん', ['ギター', '音楽'], '神奈川', 'アコースティックで合わせられる人を探しています。'),
  ('吉川 ちか', ['カフェ巡り'], '東京', '静かに作業できるカフェを開拓中です。'),
  ('原田 こう', ['将棋'], '千葉', '平日夜にオンラインで指せる相手を探しています。'),
  ('林 まい', ['園芸'], '埼玉', 'ベランダ菜園の情報交換をしたいです。'),
  ('近藤 ひろ', ['キャンプ'], '山梨', 'ソロキャンプ同士で、たまにグルキャンしませんか。'),
  ('上田 のぞみ', ['美術館'], '東京', '企画展の初日に行くのが楽しみです。'),
  ('村上 だい', ['ボルダリング'], '神奈川', '週2回ジムに通っています。初心者歓迎です。'),
  ('坂本 えり', ['語学', '英会話'], '東京', '英語でおしゃべりする練習相手を探しています。'),
];

const _workAutoApprove = {0, 2, 5, 9, 14};

const _workListings = <(String, List<String>, String, String, String)>[
  ('問い合わせの一次対応を整理', ['業務改善'], '小規模事業者の問い合わせ対応を見直す、初回の業務整理を相談したいです。', 'オンライン・週1回', '架空商店A'),
  ('採用サイトの改善案を作成', ['Web企画'], '応募者が必要な情報に迷わずたどり着ける構成を検討しています。', 'オンライン・2週間', '架空工務店B'),
  ('在庫表の自動集計', ['表計算', '業務改善'], '手作業の在庫集計を、表計算の関数で楽にしたいです。', 'オンライン・単発', '架空雑貨店C'),
  ('SNS投稿の運用ルール作り', ['広報'], '担当者が交代しても続けられる投稿ルールを作りたいです。', 'オンライン・月2回', '架空カフェD'),
  ('会計ソフトの初期設定', ['経理'], '開業したばかりで、会計ソフトの設定を相談したいです。', '対面可・東京', '架空事務所E'),
  ('予約フォームの見直し', ['Web企画'], '予約の取りこぼしを減らすフォームの改善点を知りたいです。', 'オンライン・単発', '架空整体院F'),
  ('研修資料の構成相談', ['教育'], '新人向け研修資料の章立てを一緒に考えてほしいです。', 'オンライン・3回', '架空保育園G'),
  ('補助金申請の準備手順', ['経営'], '申請書を書く前の準備手順を整理したいです。', 'オンライン・単発', '架空製作所H'),
  ('ECサイトの商品写真', ['撮影'], '商品写真の撮り方を基本から教えてほしいです。', '対面可・神奈川', '架空工房I'),
  ('社内チャットの使い方整理', ['業務改善'], 'チャネルが増えすぎたので整理方針を相談したいです。', 'オンライン・週1回', '架空設計J'),
  ('チラシの文章チェック', ['広報'], '地域向けチラシの文章を読みやすくしたいです。', 'オンライン・単発', '架空ベーカリーK'),
  ('顧客名簿の管理方法', ['表計算'], '紙の名簿をデータ化する手順を相談したいです。', 'オンライン・2回', '架空ジムL'),
  ('価格表の見直し', ['経営'], 'サービスの価格設定の考え方を相談したいです。', 'オンライン・単発', '架空美容室M'),
  ('ホームページの更新手順', ['Web企画'], '自分で更新できるよう手順書を作りたいです。', 'オンライン・2週間', '架空教室N'),
  ('アンケートの設計', ['調査'], '来店客アンケートの質問を設計したいです。', 'オンライン・単発', '架空書店O'),
  ('シフト表の作り方', ['表計算'], 'アルバイトのシフト調整を簡単にしたいです。', 'オンライン・単発', '架空食堂P'),
  ('動画の撮影と編集', ['撮影'], '紹介動画を自分たちで作る方法を知りたいです。', '対面可・埼玉', '架空農園Q'),
  ('メールの定型文作成', ['業務改善'], 'よくある問い合わせへの返信文を整えたいです。', 'オンライン・単発', '架空旅館R'),
  ('イベント集客の計画', ['広報'], '小規模イベントの集客計画を立てたいです。', 'オンライン・月1回', '架空ギャラリーS'),
  ('業務マニュアルの整備', ['教育', '業務改善'], '属人化している作業をマニュアルにしたいです。', 'オンライン・1か月', '架空運送T'),
];
