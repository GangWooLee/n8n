@AGENTS.md

## n8n 워크플로우 개발

n8n 페르소나 워크플로우 작업 시 반드시 아래 가이드를 참고하세요:
@workflows/N8N_WORKFLOW_GUIDE.md

### 핵심 주의사항
1. **JSON 파싱**: AI가 출력한 JSON이 제대로 파싱되지 않는 문제가 빈번함
   - Build Prompt에서 "JSON 한 줄 출력", "코드블록 금지", "줄바꿈은 \\n으로" 명시 필수
   - Humanize Content에서 코드블록 제거 및 폴백 파싱 로직 필수

2. **워크플로우 구조**: 노드 누락 주의
   - Fetch My Posts가 없으면 Build Prompt 오류
   - 이미지 노드들 (Decide/Search/Process) 누락 주의

3. **페르소나 설정**: authorId 매핑 확인 필수
