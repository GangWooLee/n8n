# n8n Workflow Development Guide

n8n 워크플로우 개발 시 참고할 베스트 프랙티스 가이드.

## Code 노드 JavaScript 패턴

### 반환 형식 (필수!)

```javascript
// 올바른 반환 - 반드시 배열 형식
return [
  { json: { field1: 'value1' } },
  { json: { field2: 'value2' } }
];

// 단일 아이템 반환
return [{ json: { result: 'data' } }];

// 잘못된 반환 - 이렇게 하면 안됨!
return { data: 'value' };  // 배열이 아님!
return { json: { data: 'value' } };  // 배열이 아님!
```

### 데이터 접근 패턴

```javascript
// 모든 아이템 (runOnceForAllItems 모드)
const allItems = $input.all();
for (const item of allItems) {
  const data = item.json;
}

// 첫 번째 아이템만
const firstItem = $input.first();
const data = firstItem.json;

// 각 아이템별 처리 (runOnceForEachItem 모드)
const currentItem = $input.item;
const data = currentItem.json;
```

### Webhook 데이터 접근 (중요!)

```javascript
// Webhook 데이터는 .body 아래에 있음!
const webhookData = $input.first().json.body;

// 흔한 실수 - body를 빠뜨림
const data = $input.first().json;  // body 누락!
```

### 이전 노드 데이터 참조

```javascript
// 특정 노드의 첫 번째 아이템
const nodeData = $('Node Name').first().json;

// 특정 노드의 모든 아이템
const allNodeData = $('Node Name').all();

// 현재 아이템과 매칭되는 이전 노드 아이템
const pairedData = $('Node Name').item.json;
```

## 표현식 문법 ({{ }})

### 기본 참조

```
{{ $json.fieldName }}           - 현재 아이템의 필드
{{ $json.nested.field }}        - 중첩 필드
{{ $json['field-name'] }}       - 특수문자 포함 필드
```

### 노드 참조

```
{{ $('Node Name').item.json.field }}  - 이전 노드 필드
{{ $('Node Name').all() }}            - 이전 노드 모든 아이템
{{ $('Node Name').first().json }}     - 이전 노드 첫 아이템
```

### 날짜/시간

```
{{ $now }}                      - 현재 시간 (Luxon DateTime)
{{ $now.toISO() }}              - ISO 형식
{{ $now.toFormat('yyyy-MM-dd') }}
{{ $today }}                    - 오늘 날짜
```

### 환경 변수

```
{{ $env.VARIABLE_NAME }}        - 환경 변수 참조
{{ $vars.variableName }}        - n8n 변수 참조
```

## 흔한 실수 체크리스트

| 실수 | 증상 | 해결책 |
|------|------|--------|
| 빈 배열 반환 | "No items returned" | `return [{ json: {...} }]` |
| .body 누락 | Webhook 데이터 undefined | `.json.body`로 접근 |
| 표현식 vs Code 혼동 | 문법 에러 | `{{ }}`는 표현식만, Code는 JS |
| null 체크 누락 | Cannot read property | `?.` 옵셔널 체이닝 |
| .all() 잘못된 곳 사용 | "Can't use .all() here" | `runOnceForAllItems` 모드 |
| 배열 아닌 반환 | Type 에러 | 항상 `[{json:...}]` 형식 |

## 노드별 패턴

### HTTP Request

```javascript
// 응답 형식 설정
responseFormat: 'json'  // 또는 'text'

// 헤더 설정
headerParameters: {
  parameters: [
    { name: 'Content-Type', value: 'application/json' },
    { name: 'Authorization', value: 'Bearer {{ $json.token }}' }
  ]
}
```

### Code 노드 모드

```
runOnceForAllItems: 모든 아이템을 한 번에 처리
- $input.all() 사용 가능
- 집계, 변환, 필터링에 적합

runOnceForEachItem: 각 아이템별로 실행
- $input.item 사용
- 단순 변환에 적합
```

### Merge 노드

```
mode: 'append'     - 두 입력을 단순 합침
mode: 'combine'    - 필드 기준으로 매칭
mode: 'chooseBranch' - 조건부 선택
```

### Wait 노드

```javascript
// 고정 대기
amount: 10
unit: 'minutes'

// 웹훅 대기 (resumeUrl 사용)
resume: 'webhook'
```

## AI/LangChain 노드

### Gemini 설정

```javascript
{
  modelName: 'models/gemini-2.0-flash',
  options: {
    maxOutputTokens: 2000,
    temperature: 0.85,
    // 웹 검색 활성화 (지원되는 경우)
    // enableSearchGrounding: true
  }
}
```

### Chain LLM 연결

```
ai_languageModel 연결: Gemini → Chain LLM
prompt: "={{ $json.prompt }}"
```

## 디버깅 팁

```javascript
// 콘솔 로그 (실행 로그에 표시)
console.log('Debug:', JSON.stringify(data, null, 2));

// 데이터 구조 확인
console.log('Keys:', Object.keys($input.first().json));

// 타입 확인
console.log('Type:', typeof data);
console.log('Is Array:', Array.isArray(data));
```

## 에러 처리

```javascript
try {
  const data = JSON.parse(input);
  return [{ json: { data } }];
} catch (e) {
  console.error('Parse error:', e.message);
  return [{ json: { error: e.message, raw: input } }];
}
```

## 워크플로우 패턴

### Webhook → 처리 → 응답

```
Webhook Trigger (responseMode: onReceived)
  → Process Data
  → Return Result
```

### 스케줄 → 생성 → 게시

```
Schedule Trigger
  → Load Config
  → Generate Content (AI)
  → Post to API
  → Log Result
```

### 루프 처리

```
Split In Batches (batchSize: 10)
  → Process Each
  → Merge Results
```
