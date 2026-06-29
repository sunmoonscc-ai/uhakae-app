const admin = require("firebase-admin");
const Parser = require("rss-parser");

// 로컬에서 Firebase Admin 초기화 (GCP 인증 필요)
// 구동 환경에 GOOGLE_APPLICATION_CREDENTIALS 가 필요할 수 있으나,
// firebase emulators 에서는 기본 프로젝트로 작동할 수 있습니다.
// 스크립트 실행을 위해 환경 변수나 기본 프로젝트 설정을 사용합니다.
admin.initializeApp({
  projectId: "uhakae-app"
});

const parser = new Parser();

async function fetchNow() {
  console.log("임시 수집 스크립트 시작...");
  const keyword = encodeURIComponent("세부 어학연수 OR 세부 치안");
  const feedUrl = `https://news.google.com/rss/search?q=${keyword}&hl=ko&gl=KR&ceid=KR:ko`;

  try {
    const feed = await parser.parseURL(feedUrl);
    const db = admin.firestore();
    let addedCount = 0;

    const items = feed.items.slice(0, 10);

    for (const item of items) {
      const newsQuery = await db.collection("news")
        .where("link", "==", item.link)
        .limit(1)
        .get();

      if (newsQuery.empty) {
        await db.collection("news").add({
          title: item.title,
          link: item.link,
          source: item.creator || item.source || "Google News",
          category: "cebu",
          published_at: admin.firestore.Timestamp.fromDate(new Date(item.pubDate)),
          image_url: "", 
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        addedCount++;
      }
    }

    console.log(`수집 완료! ${addedCount}개의 새 기사가 추가되었습니다.`);
  } catch (error) {
    console.error("수집 중 오류:", error);
  }
}

fetchNow();
