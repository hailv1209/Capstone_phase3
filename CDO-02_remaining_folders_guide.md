# CDO-02 Guide cho các folder còn lại trong `phase3`

## 1. Phạm vi và cách đọc tài liệu này

Tài liệu này tổng hợp 3 khu vực còn lại bạn yêu cầu đọc:

- `phase3/techx-corp-platform/`
- `phase3/techx-corp-chart/`
- `phase3/deploy/`

Vì `techx-corp-platform` có rất nhiều file generated, asset tĩnh và lockfile, mình chia theo 3 mức:

- **Mức A - phải hiểu kỹ**: file build, deploy, values, chart template, entrypoint service, config observability, config flag.
- **Mức B - nên biết vai trò**: README service, Dockerfile, proto, test/config hỗ trợ.
- **Mức C - thường không cần sửa sớm**: file generated, static image, lockfile, wrapper, binary artifacts.

Nếu mục tiêu là hoàn thành tốt Phase 3, nhóm `CDO-02` nên ưu tiên Mức A trước.

## 2. Kết luận nhanh trước khi đi vào từng file

Ba folder này tương ứng 3 lớp công việc khác nhau:

- `techx-corp-platform/` = **source thật của sản phẩm**: luồng request, dependency, feature flag, telemetry, điểm yếu reliability.
- `techx-corp-chart/` = **cách hệ thống được render thành Kubernetes objects**: replicas, env, resources, configmap, service, ingress, observability stack.
- `deploy/` = **cách nhóm bạn dùng chart/platform để build và triển khai thực tế cho TF**.

Với `CDO-02`, thứ cần quan tâm nhất để hoàn thành yêu cầu là:

1. Build image đúng registry của TF.
2. Deploy được chart với values đúng.
3. Giữ `flagd` nguyên đường dây.
4. Hiểu các service critical như `checkout`, `cart`, `product-catalog`, `product-reviews`, `frontend-proxy`, `otel-collector`.
5. Xác định chỗ nào nên harden về `readiness`, `replica`, `fallback`, `resource`, `observability`, `cost`.

---

# 3. Folder `deploy/`

## 3.1. `deploy/build-push-images.sh`

### Tác dụng

- Script build và push toàn bộ app image đa kiến trúc.
- Chạy smoke build `checkout` trước để bắt lỗi sớm.
- Sau đó gọi `make create-multiplatform-builder` và `make build-multiplatform-and-push`.

### Nhóm bạn phải làm gì với file này

- Dùng file này làm đường build chính khi cần build tất cả app images.
- Trước khi chạy, phải sửa `techx-corp-platform/.env.override` để `IMAGE_NAME` trỏ về ECR của TF.

### Lưu ý

- Comment trong file vẫn nhắc đến Docker Hub public, nhưng Phase 3 yêu cầu dùng registry/account của TF.
- Logic của script vẫn dùng được vì nó đọc từ `.env.override`.
- Đây là file **rất quan trọng** cho bước “tự build từ source và push image”.

### Gợi ý solution

- Không cần sửa script ngay nếu chỉ cần triển khai.
- Chỉ cần đổi `IMAGE_NAME` trong `.env.override` sang ECR của TF.
- Nếu muốn sạch hơn cho final delivery, có thể tạo ADR ghi rõ “không dùng registry seed, build/push sang ECR của TF theo rules”.

## 3.2. `deploy/values-observability.yaml`

### Tác dụng

- Bật 5 subchart observability:
  - `opentelemetry-collector`
  - `jaeger`
  - `prometheus`
  - `grafana`
  - `opensearch`
- Tắt toàn bộ app components.

### Nhóm bạn phải làm gì với file này

- Dùng khi muốn triển khai riêng stack observability.
- Đây là file phù hợp cho mô hình:
  - 1 namespace observability chung
  - app namespaces tách riêng theo TF

### Lưu ý

- Nếu chỉ deploy file này, storefront sẽ không chạy vì app bị tắt hết.
- Cần phối hợp với `values-app-stamp.yaml` hoặc values app khác.

### Gợi ý solution

- Với CDO, đây là hướng rất hợp lý để tách app và observability, giúp:
  - dễ kiểm soát cost
  - dễ gom dashboard
  - dễ chia namespace theo TF

## 3.3. `deploy/values-app-stamp.yaml`

### Tác dụng

- Tắt observability subcharts trong app namespace.
- Override `OTEL_COLLECTOR_NAME` để app gửi telemetry về collector chung.

### Nhóm bạn phải làm gì với file này

- Dùng khi observability được deploy riêng ở namespace khác.
- Kiểm tra collector endpoint override có đúng với namespace thực tế không.

### Lưu ý

- File comment nói rõ phải verify `OTEL_COLLECTOR_NAME`.
- Nếu sai endpoint collector, service vẫn chạy nhưng dashboard/log/trace sẽ mất hoặc thiếu.

### Gợi ý solution

- Nếu TF3 muốn tách observability tập trung, đây là file CDO nên dùng.
- Sau deploy, verify ngay:
  - metrics có vào Prometheus không
  - traces có vào Jaeger không
  - logs có vào OpenSearch không

## 3.4. `deploy/values-flagd-sync.yaml`

### Tác dụng

- Chuyển `flagd` từ file local sang nguồn flag trung tâm của BTC qua HTTP.
- Xóa sidecar `flagd-ui` local.
- Thiết lập bearer token để sync read-only.

### Nhóm bạn phải làm gì với file này

- **Bắt buộc ghép file này trong mọi lệnh deploy/upgrade của Phase 3**.
- Thay `<TOKEN>` bằng token BTC cấp.

### Lưu ý

- Đây là file quan trọng bậc nhất vì liên quan trực tiếp đến incident injection.
- Nếu quên ghép file này ở lần `helm upgrade`, cluster có thể rơi về config local.
- Không được tự ý sửa logic theo hướng làm mất kết nối với nguồn flag trung tâm.

### Gợi ý solution

- Tạo checklist deploy có dòng:
  - “đã ghép `values-flagd-sync.yaml` chưa?”
- Tạo một lệnh deploy chuẩn dùng chung cho cả TF, tránh lỗi thao tác tay.

## 3.5. `deploy/values-aio-llm.yaml`

### Tác dụng

- Cho `product-reviews` dùng LLM thật thay cho mock LLM local.
- Override:
  - `LLM_BASE_URL`
  - `LLM_MODEL`
  - `OPENAI_API_KEY`

### Nhóm bạn phải làm gì với file này

- Nếu TF3 muốn AIO cắm model thật, file này là đầu vào chính.
- CDO không nhất thiết ownership file này, nhưng phải hiểu nó vì có tác động:
  - cost
  - reliability
  - secret handling
  - latency

### Lưu ý

- Dùng model thật sẽ làm tăng cost và thêm phụ thuộc external.
- Secret `llm-api-key` phải tạo trước.

### Gợi ý solution

- Với CDO, nên yêu cầu AIO kèm:
  - cost estimate
  - fallback plan khi model lỗi/rate limit
  - impact tới SLO/latency

## 3.6. `deploy/quota.yaml`

### Tác dụng

- ResourceQuota mẫu cho namespace:
  - `requests.cpu`
  - `requests.memory`
  - `limits.cpu`
  - `limits.memory`
  - `pods`

### Nhóm bạn phải làm gì với file này

- Dùng để áp hạn mức namespace sớm.
- Có thể chỉnh số cho phù hợp TF.

### Lưu ý

- Nếu không có quota, team dễ scale/hardcode tài nguyên quá tay.
- Nếu quota quá chặt, deploy hoặc autoscaling sẽ fail.

### Gợi ý solution

- Dùng quota như một guardrail cost + safety.
- Kết hợp quota với review resource requests/limits trong chart.

---

# 4. Folder `techx-corp-chart/`

## 4.1. `techx-corp-chart/Chart.yaml`

### Tác dụng

- File metadata của Helm chart.
- Khai báo dependencies:
  - OTel Collector
  - Jaeger
  - Prometheus
  - Grafana
  - OpenSearch

### Nhóm bạn phải làm gì với file này

- Hiểu đây là chart gốc dùng để deploy toàn platform.
- Trước deploy cần `helm dependency build`.

### Lưu ý

- Các observability dependencies nằm ở đây, nên nếu subchart lỗi version hoặc repo chưa add thì deploy fail.

### Gợi ý solution

- Chuẩn hóa lệnh:
  - `helm repo add ...`
  - `helm dependency build ./techx-corp-chart`

## 4.2. `techx-corp-chart/values.yaml`

### Tác dụng

- File quan trọng nhất của chart.
- Khai báo:
  - default image repo/tag
  - env mặc định
  - replicas mặc định
  - scheduling/security
  - cấu hình từng component
  - cấu hình full observability stack

### Nhóm bạn phải làm gì với file này

- Đọc kỹ vì đây là bản đồ hạ tầng hiện tại.
- Từ file này, bạn nhìn ra:
  - service nào 1 replica
  - memory limit nào rất thấp
  - dependency nào là init container
  - service nào đọc flag
  - service nào có securityContext
  - observability pipeline đang bật ra sao

### Lưu ý

- Rất nhiều component đang `replicas: 1`.
- Nhiều memory limit rất chặt:
  - `checkout: 20Mi`
  - `currency: 20Mi`
  - `product-catalog: 20Mi`
  - `shipping: 20Mi`
- `recommendation` có memory khá cao `500Mi`.
- `flagd` đang có sidecar `flagd-ui` khi chưa override.
- `postgresql`, `valkey-cart`, `kafka` đều là in-cluster single-instance baseline.

### Gợi ý solution

- Đây là file CDO nên dùng để dựng backlog:
  - review resource requests/limits
  - review replicas cho checkout path
  - review readiness/liveness chưa cấu hình
  - review stateful dependency SPOF
- Pitch rất tốt nếu dùng chính `values.yaml` để chứng minh SPOF và under-provisioning.

## 4.3. `techx-corp-chart/values.schema.json`

### Tác dụng

- JSON schema validate cấu trúc `values.yaml`.
- Giúp biết field nào hợp lệ khi override Helm values.

### Nhóm bạn phải làm gì với file này

- Không cần sửa sớm.
- Dùng để hiểu chính xác những key nào chart hỗ trợ.

### Lưu ý

- Nếu override sai field trong values, Helm có thể không báo như bạn tưởng; schema giúp tránh lỗi này.

### Gợi ý solution

- Trước khi tạo values custom cho TF3, đọc schema để tránh typo ở:
  - `envOverrides`
  - `readinessProbe`
  - `resources`
  - `mountedConfigMaps`
  - `sidecarContainers`

## 4.4. `techx-corp-chart/README.md`

### Tác dụng

- README ngắn, chỉ nói chart dùng để deploy platform lên Kubernetes.

### Nhóm bạn phải làm gì với file này

- Chỉ dùng làm điểm xác nhận chart purpose.

### Lưu ý

- README này không đủ chi tiết; phải đọc `values.yaml` và `templates/`.

## 4.5. `techx-corp-chart/UPGRADING.md`

### Tác dụng

- Tài liệu upgrade chart/version.

### Nhóm bạn phải làm gì với file này

- Không phải file ưu tiên cho tuần đầu.

### Lưu ý

- Chỉ cần đọc nếu team định thay version chart/subchart hoặc gặp vấn đề khi nâng.

## 4.6. `techx-corp-chart/templates/component.yaml`

### Tác dụng

- Vòng lặp render tất cả component được `enabled`.
- Gọi các template:
  - deployment
  - service
  - ingress
  - configmap

### Nhóm bạn phải làm gì với file này

- Hiểu đây là entrypoint render workload.
- Khi debug “tại sao component không ra manifest”, bắt đầu từ đây.

### Lưu ý

- Nếu `enabled: false`, component sẽ không được render.

## 4.7. `techx-corp-chart/templates/serviceaccount.yaml`

### Tác dụng

- Tạo `ServiceAccount` chung cho release nếu `serviceAccount.create=true`.

### Nhóm bạn phải làm gì với file này

- Nếu team làm security/IRSA/lower privilege, đây là file phải đụng tới hoặc override.

### Lưu ý

- Hiện chart dùng một service account chung, chưa fine-grained theo service.

### Gợi ý solution

- Nếu muốn pitch theo hướng security, có thể đề xuất:
  - service account tách cho từng nhóm component nhạy cảm
  - annotation cho IAM role nếu chạy trên EKS

## 4.8. `techx-corp-chart/templates/_helpers.tpl`

### Tác dụng

- Chứa helper template cho:
  - labels
  - selector labels
  - service account name
  - merge env với `envOverrides`

### Nhóm bạn phải làm gì với file này

- Hiểu cách env được merge vì điều này ảnh hưởng trực tiếp khi dùng values override.

### Lưu ý

- `envOverrides` là kiểu upsert, không phải replace toàn bộ.
- Điều này cực quan trọng cho file `values-aio-llm.yaml`.

## 4.9. `techx-corp-chart/templates/_objects.tpl`

### Tác dụng

- Sinh ra:
  - `Deployment`
  - `Service`
  - `ConfigMap`
  - `Ingress`

### Nhóm bạn phải làm gì với file này

- Đây là file quan trọng để hiểu chart support những gì:
  - sidecar
  - init container
  - mounted config
  - readiness/liveness
  - security context
  - volumes

### Lưu ý

- Nếu muốn harden pod, phần lớn thay đổi nằm ở values chứ chưa cần sửa template.
- Có support sidecar và init container sẵn, khá linh hoạt.

### Gợi ý solution

- CDO nên ưu tiên tận dụng values override trước khi fork template.
- Chỉ sửa template nếu thật sự thiếu capability.

## 4.10. `techx-corp-chart/templates/_pod.tpl`

### Tác dụng

- Helper dựng `env` và `ports`.

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu env cuối cùng của pod được tạo ra thế nào.

### Lưu ý

- Default env + component env + envOverrides được merge tại đây.

## 4.11. `techx-corp-chart/templates/flagd-config.yaml`

### Tác dụng

- Tạo ConfigMap chứa file flag JSON local của chart.

### Nhóm bạn phải làm gì với file này

- Hiểu cơ chế local flag baseline.
- Trong Phase 3, file này chỉ là baseline; thực tế phải bị `values-flagd-sync.yaml` override sang nguồn trung tâm.

### Lưu ý

- Không được xem đây là nơi để “né” incident.

## 4.12. `techx-corp-chart/templates/grafana-config.yaml`

### Tác dụng

- Tạo ConfigMap cho:
  - alert rules
  - dashboards
  - datasources

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu dashboard/alert mặc định system đang có.
- Có thể thêm dashboard/alert của TF nếu cần.

### Lưu ý

- Grafana sidecar sẽ tự load dashboard/datasource từ các configmap này.

### Gợi ý solution

- Đây là nơi tốt để nhóm tạo dashboard riêng cho:
  - checkout success rate
  - cart health
  - DB saturation
  - error budget burn

## 4.13. `techx-corp-chart/templates/posgresql-init-config.yaml`

### Tác dụng

- Tạo ConfigMap từ SQL init file cho Postgres.

### Nhóm bạn phải làm gì với file này

- Chỉ cần hiểu luồng seed database hiện tại.

### Lưu ý

- Tên file đang là `posgresql` thay vì `postgresql`, nhưng template vẫn hoạt động vì tên file không ảnh hưởng logic.

## 4.14. `techx-corp-chart/templates/NOTES.txt`

### Tác dụng

- Helm post-install note.
- Nhắc cách port-forward `frontend-proxy` và truy cập:
  - storefront
  - Jaeger
  - Grafana
  - Load Generator
  - Feature Flags UI

### Nhóm bạn phải làm gì với file này

- Dùng như cheat sheet verify sau deploy.

### Lưu ý

- Trong Phase 3, đường `/feature` local có thể không còn usable nếu flagd-ui bị tắt qua sync values.

## 4.15. `techx-corp-chart/postgresql/init.sql`

### Tác dụng

- Seed dữ liệu Postgres cho catalog/reviews/accounting.

### Nhóm bạn phải làm gì với file này

- Chỉ cần hiểu đây là dữ liệu baseline để app hoạt động.
- Không phải chỗ ưu tiên sửa trừ khi team làm migration/data change thật sự.

## 4.16. `techx-corp-chart/flagd/demo.flagd.json`

### Tác dụng

- Baseline local flag definitions cho chart.
- Chứa toàn bộ incident flags quan trọng như:
  - `llmInaccurateResponse`
  - `llmRateLimitError`
  - `productCatalogFailure`
  - `recommendationCacheFailure`
  - `kafkaQueueProblems`
  - `paymentFailure`
  - `paymentUnreachable`
  - `failedReadinessProbe`
  - `emailMemoryLeak`

### Nhóm bạn phải làm gì với file này

- Đọc kỹ để hiểu BTC có thể tấn công hệ thống qua những kịch bản nào.
- Không dùng để tự tắt incident của Phase 3.

### Lưu ý

- Đây là một trong những file “đọc để hiểu failure mode”, không phải “sửa để né bài”.

### Gợi ý solution

- Dùng file này để dựng backlog hardening theo kịch bản:
  - payment unreachable -> fallback/UX/timeout
  - failed readiness probe -> rollout safety
  - kafka overload -> queue lag dashboard/alert
  - product catalog failure -> containment downstream

## 4.17. `techx-corp-chart/grafana/provisioning/*`

### Tác dụng

- Datasource YAML: khai báo Prometheus, Jaeger, OpenSearch.
- Dashboard JSON: dashboard mặc định.
- Alerting YAML: alert mặc định.

### Nhóm bạn phải làm gì với các file này

- Dùng để biết observability baseline hiện có gì.
- Thêm dashboard/alert riêng nếu cần.

### Lưu ý

- Đây là config hữu ích cho CDO, nhưng thường không phải nơi sửa đầu tiên.

---

# 5. Folder `techx-corp-platform/` - root level

## 5.1. `techx-corp-platform/README.md`

### Tác dụng

- Mô tả repo source của toàn platform.
- Chỉ ra layout chính:
  - `src/`
  - `docker-compose.yml`
  - `Makefile`
  - Helm chart ở folder khác

### Nhóm bạn phải làm gì với file này

- Dùng làm điểm vào repo.

## 5.2. `techx-corp-platform/.env`

### Tác dụng

- Env baseline cho chạy local Docker Compose.
- Chứa:
  - image names
  - ports
  - service addresses
  - LLM mock config
  - OTEL config

### Nhóm bạn phải làm gì với file này

- Đọc để hiểu dependency graph và default runtime.
- Không nên sửa trực tiếp nếu chỉ cần thay registry/version cho TF.

### Lưu ý

- `IMAGE_NAME` mặc định là seed/public.
- `LLM_BASE_URL` mặc định trỏ mock LLM local.

### Gợi ý solution

- Với Phase 3, dùng `.env.override` để đổi registry và version thay vì phá `.env`.

## 5.3. `techx-corp-platform/.env.override`

### Tác dụng

- File override cho image name/version.

### Nhóm bạn phải làm gì với file này

- Đây là file bạn **chắc chắn phải chỉnh** để build/push về ECR của TF.

### Lưu ý

- Hiện file vẫn trỏ `nghiadaulau/techx-corp`.
- Nếu quên sửa, bạn sẽ build/push sai đích.

## 5.4. `techx-corp-platform/.env.arm64`

### Tác dụng

- Override Java option cho môi trường arm64/macOS.

### Nhóm bạn phải làm gì với file này

- Thường không cần đụng nếu deploy Linux/EKS bình thường.

## 5.5. `techx-corp-platform/buildkitd.toml`

### Tác dụng

- Cấu hình builder buildx, giới hạn `max-parallelism=4`.

### Nhóm bạn phải làm gì với file này

- Chỉ cần hiểu nó được Makefile dùng khi tạo multi-platform builder.

## 5.6. `techx-corp-platform/Makefile`

### Tác dụng

- File automation chính của repo.
- Chứa:
  - lint/check
  - build/build-and-push
  - multi-platform build
  - start/stop
  - tests
  - protobuf generation

### Nhóm bạn phải làm gì với file này

- Dùng đây làm điểm chạy chuẩn thay vì tự gõ nhiều lệnh rời rạc.
- Đặc biệt hữu ích:
  - `create-multiplatform-builder`
  - `build-multiplatform-and-push`
  - `run-tests`

### Lưu ý

- Một số target vẫn mang tinh thần demo/local, không thay thế được chart deploy của Phase 3.
- `clean-images` đang match image public seed.

### Gợi ý solution

- Với CDO, file này giúp chuẩn hóa build pipeline nội bộ của TF.
- Nếu cần chứng minh vận hành tốt, có thể dùng make targets trong runbook.

## 5.7. `techx-corp-platform/docker-compose.yml`

### Tác dụng

- Mô tả toàn bộ platform ở chế độ local/full demo.
- Cho thấy:
  - quan hệ dependency
  - env từng service
  - memory limit
  - observability wiring
  - flagd/flagd-ui

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu dependency graph của hệ thống thật.
- Rất hữu ích khi muốn debug local hoặc trace “service nào gọi service nào”.

### Lưu ý

- Đây là local compose, không phải manifest production.
- Nhưng nó phản ánh rất rõ kiến trúc runtime.

### Gợi ý solution

- Khi viết pitch hoặc ADR, có thể dựa vào compose + chart để chứng minh call chain.

## 5.8. `techx-corp-platform/docker-compose.minimal.yml`

### Tác dụng

- Phiên bản local nhẹ hơn/full stack rút gọn.

### Nhóm bạn phải làm gì với file này

- Dùng nếu muốn local dev nhanh hơn.

### Lưu ý

- Không đại diện đầy đủ cho production path như bản full.

## 5.9. `techx-corp-platform/docker-compose-tests.yml`
## 5.10. `techx-corp-platform/docker-compose-tests_include-override.yml`

### Tác dụng

- Dùng cho test tự động, nhất là frontend/tracing tests.

### Nhóm bạn phải làm gì với file này

- Dùng khi cần regression test sau thay đổi.

### Lưu ý

- Không phải ưu tiên số 1 tuần đầu, nhưng rất hữu ích nếu nhóm bắt đầu sửa source.

## 5.11. `techx-corp-platform/package.json`
## 5.12. `techx-corp-platform/package-lock.json`

### Tác dụng

- Chứa dev tools cho markdown/lint/license/link checks của repo root.

### Nhóm bạn phải làm gì với file này

- Ít cần đụng để hoàn thành Phase 3.

## 5.13. `techx-corp-platform/pb/demo.proto`

### Tác dụng

- Hợp đồng interface chính giữa các service.
- Định nghĩa gRPC contracts cho:
  - cart
  - recommendation
  - product-catalog
  - product-review
  - shipping
  - currency
  - payment
  - email
  - checkout
  - ad
  - feature flag API

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu luồng dữ liệu giữa service.
- Chỉ sửa nếu thật sự thay đổi API contract, việc này rủi ro cao trong Phase 3.

### Lưu ý

- Đụng vào proto kéo theo regenerate nhiều language bindings.

### Gợi ý solution

- Với CDO, nên tránh sửa proto trừ khi có lý do cực mạnh.

## 5.14. `techx-corp-platform/docker-gen-proto.sh`
## 5.15. `techx-corp-platform/ide-gen-proto.sh`

### Tác dụng

- Generate protobuf bindings cho nhiều ngôn ngữ.

### Nhóm bạn phải làm gì với file này

- Chỉ dùng nếu phải sửa `demo.proto`.

### Lưu ý

- Không nên đụng tới nếu nhóm không thay API contract.

## 5.16. `techx-corp-platform/internal/tools/sanitycheck.py`

### Tác dụng

- Script kiểm tra formatting/file hygiene:
  - line ending
  - non-ASCII
  - trailing spaces
  - indent

### Nhóm bạn phải làm gì với file này

- Dùng nếu muốn giữ repo sạch khi có sửa code.

### Lưu ý

- Không phải file business-critical cho Phase 3.

---

# 6. `techx-corp-platform/src/` - các service và config quan trọng

## 6.1. `src/frontend-proxy/envoy.tmpl.yaml`

### Tác dụng

- Reverse proxy trung tâm vào toàn bộ hệ thống.
- Route:
  - `/` -> frontend
  - `/jaeger/`
  - `/grafana/`
  - `/loadgen/`
  - `/images/`
  - `/flagservice/`
  - `/feature`
  - `/otlp-http/`

### Nhóm bạn phải làm gì với file này

- Hiểu đây là cửa vào duy nhất cho người dùng và tooling UI.
- Dùng để hiểu browser-side flag provider đang đi qua đâu.

### Lưu ý

- `frontend` browser kết nối `flagd` qua route `/flagservice/`.
- Có fault filter và tracing/access log OTel.

### Gợi ý solution

- Nếu có issue frontend flag hoặc route observability UI, bắt đầu debug từ đây.

## 6.2. `src/flagd/demo.flagd.json`

### Tác dụng

- Baseline local flag source cho compose/platform.
- Giống file trong chart, mô tả các failure modes có thể bật.

### Nhóm bạn phải làm gì với file này

- Đọc để hiểu incident catalog.

### Lưu ý

- Dùng để hiểu kịch bản fail, không dùng để né bài.

## 6.3. `src/otel-collector/otelcol-config.yml`

### Tác dụng

- Config collector local/full.
- Nhận OTLP từ app.
- Thu metrics từ:
  - docker
  - host
  - nginx
  - postgres
  - redis
  - frontend-proxy
- Export:
  - traces -> Jaeger
  - metrics -> Prometheus
  - logs -> OpenSearch

### Nhóm bạn phải làm gì với file này

- Đây là file cốt lõi nếu team muốn cải tiến observability thật sự.
- Dùng để biết hiện tại đã scrape gì, chưa scrape gì.

### Lưu ý

- Có transform để giảm cardinality cho spans frontend.
- Có spanmetrics connector.

### Gợi ý solution

- CDO nên dựng backlog observability dựa trên file này:
  - thiếu alert nào
  - cần metric nào cho DB saturation / queue lag / readiness fail

## 6.4. `src/otel-collector/otelcol-config-extras.yml`

### Tác dụng

- File merge thêm cho collector.
- Hiện gần như placeholder.

### Nhóm bạn phải làm gì với file này

- Dùng khi muốn add exporter riêng, backend riêng, pipeline riêng.

### Gợi ý solution

- Nếu cần meta-monitoring hoặc external OTLP backend, đây là nơi thêm nhẹ nhất.

## 6.5. `src/prometheus/prometheus-config.yaml`

### Tác dụng

- Config Prometheus OTLP receiver, retention, promoted resource attributes.

### Nhóm bạn phải làm gì với file này

- Hiểu label strategy để viết dashboard/alert/query đúng.

### Gợi ý solution

- Khi viết dashboard theo namespace/pod/service, nhìn file này để biết label nào đang được promote.

## 6.6. `src/grafana/*`

### Tác dụng

- `grafana.ini`: cấu hình Grafana.
- provisioning dashboards/datasources/alerting: baseline observability UI.

### Nhóm bạn phải làm gì với các file này

- Dùng khi cần thêm dashboard hoặc tuning alert.

---

# 7. Các service business/critical cần hiểu trước

## 7.1. `src/checkout/main.go`

### Tác dụng

- Entry point của service checkout.
- Điều phối order end-to-end:
  - lấy cart
  - lấy product
  - convert currency
  - quote shipping
  - charge payment
  - ship order
  - empty cart
  - gửi email
  - publish Kafka

### Nhóm bạn phải làm gì với file này

- Đây là file rất quan trọng cho CDO vì checkout là revenue-critical.
- Đọc để biết:
  - dependency chain dài thế nào
  - flag nào có thể làm payment fail hoặc unreachable
  - Kafka overload được kích hoạt ra sao

### Lưu ý

- Có feature flag `paymentUnreachable`.
- Có feature flag số `kafkaQueueProblems`.
- Service gọi nhiều downstream tuần tự, nên rất nhạy với latency/failure cascade.

### Gợi ý solution

- Đây là ứng viên số 1 để harden:
  - timeout
  - retry có kiểm soát
  - circuit-breaker/fallback ở tầng gọi HTTP/grpc
  - readiness/replica/rollout safety ở các dependency critical

## 7.2. `src/cart/src/Program.cs`

### Tác dụng

- Entry point của cart service.
- Kết nối Valkey.
- Cấu hình OpenTelemetry.
- Đăng ký OpenFeature/flagd.
- Gắn health checks.

### Nhóm bạn phải làm gì với file này

- Hiểu cart là stateful service dựa trên Valkey.
- Đây là nơi liên quan tới reliability của cart path.

### Lưu ý

- Tạo cả store tốt và store `badhost:1234` trong service constructor, khả năng phục vụ kịch bản fail qua flag.

## 7.3. `src/cart/src/services/HealthCheckService.cs`

### Tác dụng

- Readiness check cho cart.
- Nếu flag `failedReadinessProbe` bật thì trả `Unhealthy`.

### Nhóm bạn phải làm gì với file này

- Đây là file rất quan trọng để hiểu incident readiness được bơm như thế nào.

### Lưu ý

- Incident readiness không phải bug ngẫu nhiên; nó được thiết kế có chủ đích.

### Gợi ý solution

- CDO nên tập trung chống blast radius:
  - rollout config đúng
  - replica đủ
  - client timeout/retry hợp lý
  - alert khi readiness fail

## 7.4. `src/product-catalog/main.go`

### Tác dụng

- Entry point catalog service.
- Kết nối PostgreSQL thật.
- Expose gRPC APIs list/get/search.
- Có feature flag `productCatalogFailure` cho product cụ thể.
- Instrument DB metrics qua `otelsql`.

### Nhóm bạn phải làm gì với file này

- Hiểu đây là service trung tâm cho browse + checkout + recommendation + reviews.

### Lưu ý

- Catalog gắn DB thật và là dependency upstream quan trọng.
- Nếu catalog fail, nhiều luồng khác bị kéo theo.

### Gợi ý solution

- Quan sát kỹ:
  - DB connection health
  - query latency
  - error rate
- Nếu pitch reliability, catalog là một điểm cần được nhắc tới.

## 7.5. `src/product-reviews/product_reviews_server.py`

### Tác dụng

- Service review + AI assistant.
- Gọi DB, gọi catalog, gọi OpenAI-compatible endpoint.
- Có logic xử lý feature flags:
  - `llmRateLimitError`
  - `llmInaccurateResponse`

### Nhóm bạn phải làm gì với file này

- Hiểu đây là vùng giao nhau giữa app + AI + observability.
- Dù AIO ownership phần AI, CDO vẫn cần hiểu vì nó ảnh hưởng reliability và customer trust.

### Lưu ý

- Khi LLM rate limit, service trả fallback message.
- AI path có thể tạo lỗi business nhưng không phải luồng revenue-critical bằng checkout.

### Gợi ý solution

- Với CDO, nên ưu tiên:
  - degrade gracefully
  - tách rõ “AI phụ trợ” khỏi “checkout critical”
  - alert riêng cho AI lỗi nhưng không để kéo sập storefront

## 7.6. `src/llm/app.py`

### Tác dụng

- Mock LLM server theo format OpenAI Chat Completions.
- Trả summary dựng sẵn từ JSON.
- Có thể cố tình:
  - trả summary sai
  - trả rate limit 429

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu hành vi mock AI và các kịch bản failure AI.

### Lưu ý

- Đây không phải LLM thật; là black-box mô phỏng.

### Gợi ý solution

- Nếu AIO cắm model thật, CDO cần yêu cầu giữ fallback path và đo cost.

## 7.7. `src/payment/charge.js`

### Tác dụng

- Logic charge payment.
- Dùng flag `paymentFailure` để fail theo xác suất.

### Nhóm bạn phải làm gì với file này

- Hiểu đây là nơi incident payment được hiện thực.

### Lưu ý

- Failure có thể theo tỷ lệ, không phải always-on.
- Điều này làm incident khó đoán hơn khi nhìn bằng mắt thường.

### Gợi ý solution

- CDO nên thêm:
  - alert payment error rate
  - correlation dashboard checkout vs payment
  - timeout budget và retry policy thận trọng

## 7.8. `src/recommendation/recommendation_server.py`

### Tác dụng

- Service recommendation.
- Có kịch bản `recommendationCacheFailure` gây cache leak/hành vi bất thường.

### Nhóm bạn phải làm gì với file này

- Hiểu đây là vùng performance/memory risk.

### Lưu ý

- `recommendation` đang có memory limit cao hơn bình thường trong values vì use case flag này.

### Gợi ý solution

- Nếu muốn làm trụ Performance Efficiency/Cost, đây là target tốt để phân tích memory behavior.

## 7.9. `src/frontend/pages/_app.tsx`

### Tác dụng

- Entry point frontend app.
- Browser-side tracer.
- Browser-side OpenFeature provider kết nối `flagd` qua `frontend-proxy`.

### Nhóm bạn phải làm gì với file này

- Hiểu frontend cũng là một phần của đường dây flag, không chỉ backend.

### Lưu ý

- Browser dùng `FlagdWebProvider` với `pathPrefix: 'flagservice'`.
- Nếu proxy route sai hoặc flag service lỗi, frontend feature behavior sẽ lệch.

## 7.10. `src/frontend/README.md`

### Tác dụng

- Mô tả frontend gồm client UI + API layer.

### Nhóm bạn phải làm gì với file này

- Dùng để hiểu frontend không chỉ là giao diện, mà còn bọc các backend bằng REST endpoints.

## 7.11. `src/frontend-proxy/README.md`

### Tác dụng

- Nói rõ Envoy config được generate từ template bằng env vars.

### Nhóm bạn phải làm gì với file này

- Chỉ cần nhớ mọi thay đổi routing đều quay về `envoy.tmpl.yaml`.

---

# 8. Các service/phần còn lại - vai trò và mức ưu tiên

## 8.1. `src/accounting/*`

- Vai trò: consumer Kafka, ghi order vào DB.
- Nhóm cần làm gì: hiểu đây là downstream async sau checkout.
- Lưu ý: lỗi ở đây ít trực tiếp bằng checkout, nhưng quan trọng cho hậu xử lý đơn hàng.

## 8.2. `src/fraud-detection/*`

- Vai trò: consumer Kafka kiểm tra fraud.
- Nhóm cần làm gì: chủ yếu hiểu đây là downstream async và có thể chịu ảnh hưởng queue lag.

## 8.3. `src/ad/*`

- Vai trò: trả ads, có flag gây CPU/GC/failure.
- Nhóm cần làm gì: dùng như bài toán containment cho luồng browse/search.

## 8.4. `src/shipping/*`

- Vai trò: quote + tracking.
- Nhóm cần làm gì: hiểu nó nằm trong checkout path.

## 8.5. `src/quote/*`

- Vai trò: tính shipping cost.
- Nhóm cần làm gì: biết shipping phụ thuộc quote.

## 8.6. `src/currency/*`

- Vai trò: convert tiền tệ.
- Nhóm cần làm gì: đọc nếu cần điều tra checkout latency/failure sâu hơn.

## 8.7. `src/email/*`

- Vai trò: render email confirmation.
- Có flag memory leak theo catalog flags.
- Nhóm cần làm gì: nên gắn alert và log correlation, nhưng thường không là ưu tiên số 1 trước checkout.

## 8.8. `src/kafka/*`

- Vai trò: backbone async order events.
- Nhóm cần làm gì: rất đáng quan tâm nếu làm reliability/observability/lag monitoring.

## 8.9. `src/load-generator/*`

- Vai trò: tạo synthetic traffic.
- Nhóm cần làm gì: dùng rất tốt để verify thay đổi dưới tải.

## 8.10. `src/flagd-ui/*`

- Vai trò: UI local để sửa flag file.
- Nhóm cần làm gì: hiểu cơ chế local demo thôi.

### Lưu ý cực quan trọng

- Trong Phase 3, `flagd-ui` local không phải cơ chế chính nữa.
- Khi sync từ BTC bật lên, local editing không còn là đường hợp lệ.

---

# 9. Nhóm file “thường không nên sửa sớm”

Các file sau thường chỉ nên đọc biết vai trò, không nên đụng sớm nếu mục tiêu là hoàn thành đề:

- `package-lock.json`, `Cargo.lock`, `Gemfile.lock`, `mix.lock`
- `gradlew*`, `gradle-wrapper.jar`, `gradle-wrapper.properties`
- `generated proto files` như `demo_pb2.py`, `demo.pb.go`, `demo_grpc.pb.go`, C++ generated files
- static assets trong `src/image-provider/static/*`
- icon, css component lẻ trong frontend nếu không có yêu cầu UI

Lý do:

- Chúng ít mang giá trị trực tiếp cho SLO/budget/incident handling của Phase 3.

---

# 10. Tôi nghĩ CDO-02 nên làm gì với 3 folder này để hoàn thành yêu cầu

## 10.1. Việc nên làm ngay

1. Sửa `techx-corp-platform/.env.override` sang ECR của TF3.
2. Dùng `deploy/build-push-images.sh` để build/push images.
3. Dùng chart + values để deploy:
   - observability
   - app stamp
   - `values-flagd-sync.yaml`
4. Dùng `frontend-proxy`, Grafana, Jaeger, collector config để verify telemetry đầy đủ.
5. Rà `values.yaml` và các entrypoint critical để dựng backlog reliability.

## 10.2. Backlog CDO rất hợp lý khi nhìn từ source/chart

1. Hardening `checkout` path.
2. Alert/dashboard cho payment, catalog, cart, Kafka lag, readiness fail.
3. Review resource limits và replica strategy trong `values.yaml`.
4. Review SPOF:
   - `postgresql`
   - `valkey-cart`
   - `kafka`
5. Thiết kế rollback/deploy-safe cho các thay đổi Helm values.

## 10.3. Solution mình đề xuất

### Hướng 1: “ít rủi ro, điểm cao”

- Tập trung reliability + observability + cost guardrail.
- Không làm migration lớn ngay.
- Chốt pitch quanh:
  - checkout critical
  - readiness/replica/rollout
  - dashboard/alert/error budget
  - guardrail cost

### Hướng 2: “có nâng cấp nhưng vẫn kiểm soát được”

- Tách observability namespace riêng.
- App namespace dùng `values-app-stamp.yaml`.
- Chuẩn hóa deploy pipeline + rollback.
- Làm thêm quota/budget/anomaly detection.

### Hướng 3: “tham vọng hơn”

- Sau khi đã ổn reliability baseline, mới cân nhắc:
  - managed DB/cache/message queue
  - security hardening sâu hơn
  - service account/IRSA split

Nhưng chỉ nên làm nếu:

- đã có baseline đo được
- không đe dọa SLO
- không phá budget
- có rollback rõ ràng

---

# 11. Tóm tắt ngắn nhất

Nếu chỉ nhớ 1 ý cho 3 folder này:

> `techx-corp-platform` cho bạn biết hệ thống hoạt động ra sao, `techx-corp-chart` cho bạn biết nó được triển khai ra sao, còn `deploy` là cách bạn biến hai thứ đó thành môi trường thật của TF3.

Với `CDO-02`, thứ quan trọng nhất không phải đọc hết mọi file generated, mà là:

- hiểu `values.yaml`
- hiểu `flagd` và incident flags
- hiểu `checkout/cart/product-catalog/product-reviews/frontend-proxy/otel-collector`
- chuẩn hóa build/push/deploy
- dùng các file này để dựng backlog reliability/observability/cost có thể bảo vệ được trong pitch

## 12. Phần mình đã đọc để viết file này

### `deploy/`

- `build-push-images.sh`
- `values-observability.yaml`
- `values-flagd-sync.yaml`
- `values-app-stamp.yaml`
- `values-aio-llm.yaml`
- `quota.yaml`

### `techx-corp-chart/`

- `Chart.yaml`
- `values.yaml`
- `values.schema.json`
- `README.md`
- `templates/component.yaml`
- `templates/serviceaccount.yaml`
- `templates/_helpers.tpl`
- `templates/_objects.tpl`
- `templates/_pod.tpl`
- `templates/flagd-config.yaml`
- `templates/grafana-config.yaml`
- `templates/posgresql-init-config.yaml`
- `templates/NOTES.txt`
- `flagd/demo.flagd.json`
- `postgresql/init.sql`

### `techx-corp-platform/`

- `README.md`
- `.env`
- `.env.override`
- `.env.arm64`
- `buildkitd.toml`
- `Makefile`
- `docker-compose.yml`
- `docker-compose.minimal.yml`
- `docker-compose-tests.yml`
- `docker-compose-tests_include-override.yml`
- `package.json`
- `pb/demo.proto`
- `docker-gen-proto.sh`
- `ide-gen-proto.sh`
- `internal/tools/sanitycheck.py`
- `src/frontend-proxy/envoy.tmpl.yaml`
- `src/flagd/demo.flagd.json`
- `src/otel-collector/otelcol-config.yml`
- `src/otel-collector/otelcol-config-extras.yml`
- `src/prometheus/prometheus-config.yaml`
- các README và entrypoint chính của các service critical
