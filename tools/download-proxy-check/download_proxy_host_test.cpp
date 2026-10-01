#include "download_core.h"

#include <chrono>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>

namespace {

using aira::download::DownloadManager;
using aira::download::TaskOptions;
using aira::download::TaskSnapshot;
using aira::download::TaskState;

int g_failures = 0;

void Fail(const std::string& name, const std::string& message) {
  std::cerr << "FAIL " << name << ": " << message << '\n';
  g_failures += 1;
}

std::string ReadFile(const std::string& path) {
  std::ifstream input(path, std::ios::binary);
  return std::string(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
}

TaskSnapshot RunDownload(const TaskOptions& options) {
  DownloadManager manager;
  const std::int64_t handle = manager.Create(options);
  const auto task = manager.Find(handle);
  if (task == nullptr || !task->Start()) {
    TaskSnapshot failed;
    failed.state = TaskState::kFailed;
    failed.error_message = "failed to start download task";
    return failed;
  }
  const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
  TaskSnapshot snapshot;
  while (std::chrono::steady_clock::now() < deadline) {
    snapshot = task->Snapshot();
    if (snapshot.state == TaskState::kCompleted || snapshot.state == TaskState::kFailed ||
        snapshot.state == TaskState::kCanceled) {
      break;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
  }
  manager.Release(handle);
  return snapshot;
}

TaskOptions ProxyOptions(const std::string& url, const std::string& path, const std::string& scheme,
                         const std::string& host, int port, const std::string& username,
                         const std::string& password, const std::string& no_proxy) {
  TaskOptions options;
  options.url = url;
  options.target_path = path;
  options.proxy_scheme = scheme;
  options.proxy_host = host;
  options.proxy_port = port;
  options.proxy_username = username;
  options.proxy_password = password;
  options.proxy_noproxy = no_proxy;
  return options;
}

void Expect(const std::string& name, const TaskSnapshot& snapshot, TaskState state,
            const std::string& body_path, const std::string& body, const std::string& diagnostic_part,
            const std::string& log_text, const std::string& log_must, const std::string& log_must_not) {
  if (snapshot.state != state) {
    Fail(name, std::string("state=") + aira::download::TaskStateName(snapshot.state) +
      " error=" + snapshot.error_message + " diagnostic=" + snapshot.diagnostic_message);
    return;
  }
  if (!body.empty()) {
    const std::string actual = ReadFile(body_path);
    if (actual != body) {
      Fail(name, "body=[" + actual + "] diagnostic=" + snapshot.diagnostic_message);
      return;
    }
  }
  if (!diagnostic_part.empty() && snapshot.diagnostic_message.find(diagnostic_part) == std::string::npos) {
    Fail(name, "diagnostic missing " + diagnostic_part + " actual=" + snapshot.diagnostic_message);
    return;
  }
  if (!log_must.empty() && log_text.find(log_must) == std::string::npos) {
    Fail(name, "proxy log missing " + log_must);
    return;
  }
  if (!log_must_not.empty() && log_text.find(log_must_not) != std::string::npos) {
    Fail(name, "proxy log unexpectedly contains " + log_must_not);
    return;
  }
  std::cout << "PASS " << name << '\n';
}

std::string LogSince(const std::string& log_path, std::size_t offset) {
  const std::string log_text = ReadFile(log_path);
  if (offset >= log_text.size()) {
    return {};
  }
  return log_text.substr(offset);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 8) {
    std::cerr << "usage: download_proxy_host_test origin_port http_proxy_port socks_port "
                 "log_file work_dir user password\n";
    return 2;
  }
  const int origin_port = std::stoi(argv[1]);
  const int http_port = std::stoi(argv[2]);
  const int socks_port = std::stoi(argv[3]);
  const std::string log_path = argv[4];
  const std::string work_dir = argv[5];
  const std::string user = argv[6];
  const std::string password = argv[7];
  const std::string unresolvable = "http://release-assets.githubusercontent.com.invalid";

  {
    const std::string name = "http-proxy";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/http-proxy.bin";
    const TaskSnapshot snapshot = RunDownload(ProxyOptions(
      unresolvable + "/case-http", path, "http", "127.0.0.1", http_port, "", "", ""));
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kCompleted, path, "proxied-ok\n", "proxyUsed=1",
           log_text, "HTTP GET " + unresolvable + "/case-http", "");
  }
  {
    const std::string name = "http-proxy-auth";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/http-auth.bin";
    const TaskSnapshot snapshot = RunDownload(ProxyOptions(
      unresolvable + "/case-auth", path, "http", "127.0.0.1", http_port, user, password, ""));
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kCompleted, path, "proxied-ok\n", "proxyUsed=1",
           log_text, "AUTH accept GET " + unresolvable + "/case-auth", password);
  }
  {
    const std::string name = "http-proxy-rejected-auth";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/http-rejected.bin";
    const TaskSnapshot snapshot = RunDownload(ProxyOptions(
      unresolvable + "/case-rejected", path, "http", "127.0.0.1", http_port, user, "wrong-password", ""));
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kFailed, path, "", "proxyUsed=1",
           log_text, "AUTH reject GET " + unresolvable + "/case-rejected", "");
  }
  {
    const std::string name = "https-through-http-proxy";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/https-connect.bin";
    TaskOptions options = ProxyOptions(
      "https://release-assets.githubusercontent.com.invalid/case-connect",
      path, "http", "127.0.0.1", http_port, "", "", "");
    const TaskSnapshot snapshot = RunDownload(options);
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kFailed, path, "", "proxyUsed=1",
           log_text, "HTTP CONNECT release-assets.githubusercontent.com.invalid:443", "");
  }
  {
    const std::string name = "socks5-remote-dns";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/socks.bin";
    const TaskSnapshot snapshot = RunDownload(ProxyOptions(
      unresolvable + "/case-socks", path, "socks5", "127.0.0.1", socks_port, "", "", ""));
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kCompleted, path, "socks-proxied-ok\n",
           "proxyScheme=socks5h", log_text,
           "SOCKS domain release-assets.githubusercontent.com.invalid:80", "SOCKS ip ");
  }
  {
    const std::string name = "bypass-direct";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/bypass.bin";
    const std::string url = "http://127.0.0.1:" + std::to_string(origin_port) + "/case-bypass";
    const TaskSnapshot snapshot = RunDownload(ProxyOptions(
      url, path, "http", "127.0.0.1", http_port, "", "", "127.0.0.1"));
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kCompleted, path, "direct-ok\n", "proxyUsed=0",
           log_text, "ORIGIN GET /case-bypass", "HTTP GET " + url);
  }
  {
    const std::string name = "proxy-disabled";
    const std::size_t offset = ReadFile(log_path).size();
    const std::string path = work_dir + "/direct.bin";
    const std::string url = "http://127.0.0.1:" + std::to_string(origin_port) + "/case-direct";
    TaskOptions options;
    options.url = url;
    options.target_path = path;
    const TaskSnapshot snapshot = RunDownload(options);
    const std::string log_text = LogSince(log_path, offset);
    Expect(name, snapshot, TaskState::kCompleted, path, "direct-ok\n", "proxyConfigured=0",
           log_text, "ORIGIN GET /case-direct", "HTTP GET " + url);
  }

  if (g_failures != 0) {
    std::cerr << g_failures << " download proxy checks failed\n";
    return 1;
  }
  std::cout << "download proxy checks passed\n";
  return 0;
}
