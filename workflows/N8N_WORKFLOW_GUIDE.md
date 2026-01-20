# N8N 워크플로우 개발 가이드

이 문서는 n8n 페르소나 워크플로우 개발 시 발생했던 문제들과 해결책을 정리한 것입니다.
앞으로 워크플로우 수정 시 반드시 이 가이드를 참고하세요.

---

## 1. 워크플로우 구조

### 필수 노드 및 연결 순서
```
Schedule Trigger → Check Schedule → Persona Config → Fetch My Posts → Build Prompt
→ Generate Content → Humanize Content → Decide Image Attachment → Search Image
→ Process Image URLs → Post to API → Log Execution
```

### 누락되기 쉬운 노드
- **Fetch My Posts**: 이전 글 학습 기능에 필요. 없으면 Build Prompt에서 오류 발생
- **Decide Image Attachment**: 30% 확률 이미지 첨부
- **Search Image**: Unsplash API 호출
- **Process Image URLs**: 이미지 URL 추출

### 연결 확인 방법
```sql
sqlite3 ~/.n8n/database.sqlite "SELECT connections FROM workflow_entity WHERE name = 'Persona - 워크플로우명'"
```

---

## 2. JSON 파싱 문제 (가장 빈번한 오류)

### 문제 상황
AI가 출력한 JSON이 제대로 파싱되지 않아 제목/본문이 이상하게 나옴

### 원인 1: 마크다운 코드 블록
```
AI 출력:
```json
{"title": "제목", "content": "내용"}
```

결과: 제목이 "```json"으로 표시됨
```

**해결책**: Humanize Content에서 코드 블록 제거
```javascript
aiResponse = aiResponse.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();
```

### 원인 2: JSON 문자열 내 실제 줄바꿈
```
AI 출력:
{
  "title": "제목",
  "content": "내용에
  줄바꿈이
  있음"
}

→ JSON.parse() 실패 (문자열 내 실제 줄바꿈은 허용 안됨)
```

**해결책 1**: Build Prompt에서 명시
```
줄바꿈은 \n으로 표현 (실제 엔터 금지)
올바른 예시: {"title": "제목", "content": "야, 이거...\\n\\n어제 멘토링에서..."}
```

**해결책 2**: Humanize Content에서 변환
```javascript
// content 값 내부의 줄바꿈을 \n으로 변환 후 파싱
const contentMatch = jsonStr.match(/"content"\s*:\s*"([\s\S]*?)"\s*[,}]/);
if (contentMatch) {
  const fixedContent = contentMatch[1].replace(/\n/g, '\\n');
  // ... 파싱
}
```

### 원인 3: JSON 외 텍스트 포함
```
AI 출력:
여기 제가 작성한 글입니다:
{"title": "제목", "content": "내용"}
```

**해결책**: Build Prompt에서 강조
```
절대 금지:
- ```json 코드 블록 사용 금지
- JSON 외 다른 텍스트 추가 금지
```

---

## 3. Build Prompt 작성 규칙

### 출력 형식 템플릿 (필수)
```javascript
[출력 형식 - 매우 중요!!!]
반드시 아래 형식의 JSON 한 줄로만 출력하세요:
{"title": "제목 10-30자", "content": "본문 400-800자"}

절대 금지:
- \`\`\`json 코드 블록 사용 금지
- JSON 외 다른 텍스트 추가 금지
- 줄바꿈은 \\n으로 표현 (실제 엔터 금지)

올바른 예시:
{"title": "제목", "content": "야, 이거...\\n\\n어제 멘토링에서..."}

잘못된 예시 (이렇게 하지 마세요):
\`\`\`json
{
  "title": "제목",
  "content": "내용"
}
\`\`\`
```

### 글자수 제한 명시
페르소나별로 글자수 제한이 다를 수 있음. 반드시 명시할 것.
```javascript
// 예시: 스타트업러버는 400-800자
postTypeInfo: {
  minLength: 400,
  maxLength: 800
}
```

---

## 4. Humanize Content 파싱 로직 (필수 포함)

```javascript
// 0. 마크다운 코드 블록 제거
aiResponse = aiResponse.replace(/^```json\s*/i, '').replace(/```\s*$/, '').trim();

// 1. JSON 파싱 시도
try {
  const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    let jsonStr = jsonMatch[0];
    // 문자열 내 줄바꿈 처리
    // ... 파싱
  }
} catch (e) {}

// 2. 직접 추출 폴백
const titleExtract = aiResponse.match(/"title"\s*:\s*"([^"]+)"/);
const contentExtract = aiResponse.match(/"content"\s*:\s*"([\s\S]*?)"\s*[,}]\s*$/m);

// 3. 제목 검증 (이상한 제목 방지)
if (!title || title === '```json' || title === '```' || title.startsWith('{')) {
  // content에서 추출
}
```

---

## 5. Persona Config 필수 필드

```javascript
const persona = {
  "id": "persona_id",
  "nickname": "닉네임",
  "email": "email@seed.community",
  "apiToken": "API_TOKEN",
  "authorId": 13,  // 필수! Fetch My Posts에서 사용

  // 글 스타일
  "speechStyle": "말투 설명",
  "expressions": ["사용 가능한 표현들"],
  "forbiddenExpressions": ["금지 표현들"],  // 욕설 등
  "neverUse": ["절대 안 쓰는 톤"],

  // 글 길이 제한
  "lengthConstraint": {
    "min": 400,
    "max": 800
  },

  // ...
};
```

### Author ID 매핑
| author_id | 닉네임 |
|-----------|--------|
| 13 | 스타트업러버 |
| 14 | 코딩마스터 |
| 15 | 디자인히어로 |
| 16 | 마케터진 |
| 17 | 투자러닝 |
| 18 | 개발새발 |
| 19 | 기획충 |
| 20 | 데이터맨 |
| 21 | 창업멘토 |
| 22 | 법률마스터 |
| 23 | AI연구원 |
| 24 | 콘텐츠퀸 |
| 25 | 세일즈킹 |
| 26 | 인사담당 |
| 27 | 재무고수 |

---

## 6. Post to API 설정

### 필수 파라미터
```javascript
{
  "method": "POST",
  "url": "https://undrewai.com/api/v1/posts",
  "jsonBody": "={{ JSON.stringify({ post: { title: $json.title, content: $json.content, category: \"free\", image_urls: $json.image_urls || [] } }) }}"
}
```

### 헤더 설정
```javascript
{
  "Authorization": "Bearer {API_TOKEN}",
  "Content-Type": "application/json"
}
```

---

## 7. 이미지 첨부 기능

### Decide Image Attachment
- 30% 확률로 이미지 첨부 결정
- 영어 키워드 사용 (Unsplash는 영어 검색이 잘 됨)

### Search Image (Unsplash API)
```
URL: https://api.unsplash.com/search/photos?query={{ encodeURIComponent($json.searchKeywords) }}&per_page=3&orientation=landscape
Header: Authorization: Client-ID {UNSPLASH_ACCESS_KEY}
```

### Process Image URLs
- `$('Decide Image Attachment')` 참조로 title, content 가져오기
- Unsplash 응답에서 `results[].urls.regular` 추출

---

## 8. 자주 발생하는 오류 체크리스트

### 워크플로우 수정 전 확인
- [ ] 모든 필수 노드가 있는가?
- [ ] 노드 연결이 올바른가?
- [ ] Fetch My Posts의 authorId가 올바른가?
- [ ] Post to API에 image_urls가 포함되어 있는가?

### Build Prompt 수정 전 확인
- [ ] JSON 출력 형식이 명확하게 지시되어 있는가?
- [ ] 코드 블록 금지가 명시되어 있는가?
- [ ] 줄바꿈을 \n으로 표현하라고 명시되어 있는가?
- [ ] 글자수 제한이 명시되어 있는가?

### Humanize Content 수정 전 확인
- [ ] 마크다운 코드 블록 제거 로직이 있는가?
- [ ] JSON 파싱 실패 시 폴백 로직이 있는가?
- [ ] 제목이 "```json"인 경우 처리가 있는가?

---

## 9. 디버깅 방법

### 워크플로우 노드 확인
```bash
sqlite3 ~/.n8n/database.sqlite "SELECT json_extract(nodes, '$') FROM workflow_entity WHERE name = 'Persona - 워크플로우명'" | python3 -c "import sys, json; print(json.dumps(json.loads(sys.stdin.read()), indent=2, ensure_ascii=False))"
```

### 특정 노드 코드 확인
```bash
sqlite3 ~/.n8n/database.sqlite "SELECT json_extract(nodes, '$') FROM workflow_entity WHERE name = 'Persona - 워크플로우명'" | python3 -c "import sys, json; nodes = json.loads(sys.stdin.read()); node = [n for n in nodes if n.get('name') == '노드명'][0]; print(node['parameters']['jsCode'])"
```

### 연결 관계 확인
```bash
sqlite3 ~/.n8n/database.sqlite "SELECT connections FROM workflow_entity WHERE name = 'Persona - 워크플로우명'"
```

---

## 10. 페르소나별 특수 설정

각 페르소나는 다른 특성을 가질 수 있음. 반드시 확인할 것:
- 글자수 제한 (min/max)
- 욕설 허용 여부
- 말투 (반말/존댓말)
- 이모티콘 사용 여부
- 특수 표현 (ㅋㅋㅋ, ㄷㄷ 등)

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2024-01-16 | 초기 문서 작성 |
| - | JSON 파싱 문제 해결책 추가 |
| - | 워크플로우 구조 문서화 |
| - | 페르소나 설정 가이드 추가 |
