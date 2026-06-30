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

    // 최근 저장된 뉴스 제목들을 가져와 유사성 검사에 활용 (최대 50개)
    const recentNewsSnapshot = await db.collection("news")
      .orderBy("published_at", "desc")
      .limit(50)
      .get();
      
    const recentTitles = recentNewsSnapshot.docs.map(doc => doc.data().title || "");

    // 구글 뉴스 제목에서 " - 언론사명" 형태의 꼬리말을 제거하는 함수
    const cleanTitle = (title) => {
      const parts = title.split(' - ');
      if (parts.length > 1) {
        parts.pop(); // 마지막 언론사 부분 제거
        return parts.join(' - ').trim();
      }
      return title.trim();
    };

    for (const item of items) {
      // 1. 링크 기반 정확한 중복 검사
      const newsQuery = await db.collection("news")
        .where("link", "==", item.link)
        .limit(1)
        .get();

      if (!newsQuery.empty) {
        continue; // 이미 있는 링크면 건너뜀
      }

      // 2. 제목 기반 유사성 중복 검사
      const baseTitle = cleanTitle(item.title);
      const isSimilar = recentTitles.some(existingTitle => {
        const existingBase = cleanTitle(existingTitle);
        // 문자열이 서로 포함되는 관계면 유사한 뉴스로 간주
        return existingBase.includes(baseTitle) || baseTitle.includes(existingBase);
      });

      if (isSimilar) {
        console.log(`유사한 뉴스 필터링됨: ${item.title}`);
        continue;
      }

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
      
      // 현재 실행 중인 루프 내에서 중복되는 항목이 있을 수 있으므로 방금 추가한 제목을 배열에 삽입
      recentTitles.push(item.title);
      addedCount++;
    }

    console.log(`뉴스 수집 완료. ${addedCount}개의 새 기사가 추가되었습니다.`);
  } catch (error) {
    console.error("뉴스 수집 중 오류 발생:", error);
  }
});
