const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const Parser = require("rss-parser");

admin.initializeApp();
const parser = new Parser();

// 필리핀 시간(Asia/Manila) 기준 매 시 정각(00분)마다 실행
exports.fetchNews = onSchedule({
  schedule: "0 * * * *",
  timeZone: "Asia/Manila",
}, async (event) => {
  console.log("뉴스 수집을 시작합니다.");

  // 구글 뉴스 RSS URL (키워드: 세부 어학연수, 필리핀 세부, 세부 국제학교, 대구 제외)
  const keyword = encodeURIComponent('"필리핀 세부" OR "세부 어학연수" OR "세부 국제학교" -"대구"');
  const feedUrl = `https://news.google.com/rss/search?q=${keyword}&hl=ko&gl=KR&ceid=KR:ko`;

  try {
    const feed = await parser.parseURL(feedUrl);
    const db = admin.firestore();
    let addedCount = 0;

    // 최신 기사 10개만 처리
    const items = feed.items.slice(0, 10);

    for (const item of items) {
      // 문서 ID로 사용할 고유 식별자 (링크 또는 guid 해싱 등을 사용할 수 있지만, 편의상 문서 쿼리로 중복 검사)
      const newsQuery = await db.collection("news")
        .where("link", "==", item.link)
        .limit(1)
        .get();

      if (newsQuery.empty) {
        // DB에 없는 새로운 뉴스면 저장
        await db.collection("news").add({
          title: item.title,
          link: item.link,
          source: item.creator || item.source || "Google News",
          category: "cebu",
          published_at: admin.firestore.Timestamp.fromDate(new Date(item.pubDate)),
          image_url: "", // RSS에서 썸네일을 제공하지 않는 경우가 많음
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        addedCount++;
      }
    }

    console.log(`뉴스 수집 완료. ${addedCount}개의 새 기사가 추가되었습니다.`);
  } catch (error) {
    console.error("뉴스 수집 중 오류 발생:", error);
  }
});
