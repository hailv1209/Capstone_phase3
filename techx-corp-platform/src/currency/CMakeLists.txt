cmake_minimum_required(VERSION 3.26)
project(currency)

find_package(Protobuf REQUIRED)
find_package(gRPC CONFIG REQUIRED)
find_package(opentelemetry-cpp CONFIG REQUIRED)

set(GENERATED_PROTOBUF_PATH "${CMAKE_BINARY_DIR}/generated/proto")
set(DEMO_PB_CPP_FILE "${GENERATED_PROTOBUF_PATH}/demo.pb.cc")
set(DEMO_GRPC_PB_CPP_FILE "${GENERATED_PROTOBUF_PATH}/demo.grpc.pb.cc")
set(HEALTH_PB_CPP_FILE "${GENERATED_PROTOBUF_PATH}/grpc/health/v1/health.pb.cc")
set(HEALTH_GRPC_PB_CPP_FILE "${GENERATED_PROTOBUF_PATH}/grpc/health/v1/health.grpc.pb.cc")

if (NOT EXISTS "${DEMO_PB_CPP_FILE}" OR
    NOT EXISTS "${DEMO_GRPC_PB_CPP_FILE}" OR
    NOT EXISTS "${HEALTH_PB_CPP_FILE}" OR
    NOT EXISTS "${HEALTH_GRPC_PB_CPP_FILE}")
  add_subdirectory(genproto)
else()
  add_library(
    demo-proto
    "${DEMO_PB_CPP_FILE}"
    "${DEMO_GRPC_PB_CPP_FILE}"
    "${HEALTH_PB_CPP_FILE}"
    "${HEALTH_GRPC_PB_CPP_FILE}"
  )
  target_link_libraries(demo-proto gRPC::grpc++ protobuf::libprotobuf)
endif()

include_directories("${GENERATED_PROTOBUF_PATH}" "${OPENTELEMETRY_CPP_INCLUDE_DIRS}")

add_executable(currency src/server.cpp)
add_dependencies(currency demo-proto)
target_link_libraries(
    currency demo-proto protobuf::libprotobuf
     ${OPENTELEMETRY_CPP_LIBRARIES} gRPC::grpc++)

install(TARGETS currency DESTINATION bin)
