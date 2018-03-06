#include <cstdio>
#include <cstdlib>
#include <string>
#include <json/json.h>

int main(int argc, char *argv[])
{
  if (argc != 2) {
    fprintf(stderr, "usage: %s jsonpath\n", argv[0]);
    return EXIT_FAILURE;
  }

  std::string json;
  char buffer[256];
  while (fgets(buffer, 256, stdin)) {
    json.append(buffer);
  }

  try {
    Json::Path path(argv[1]);

    Json::Reader reader;
    Json::Value  root;
    if (!reader.parse(json, root)) {
      fprintf(stderr, "parse %s error", json.c_str());
      return EXIT_FAILURE;
    }

    const Json::Value &value = path.resolve(root);
    if (value.isString()) {
      printf("%s\n", value.asCString());
    } else if (value.isInt()) {
      printf("%d\n", (int) value.asInt());
    } else if (value.isDouble()) {
      printf("%f\n", value.asDouble());
    } else if (value.isBool()) {
      printf("%s\n", value.asBool() ? "true" : "false");
    } else if (value.isNull()) {
      printf("\n");
    } else {
      json = Json::FastWriter().write(value);
      printf("%s", json.c_str());
    }
  } catch (const std::exception &e) {
    fprintf(stderr, "json %s, path %s error %s", json.c_str(), argv[1], e.what());
    return EXIT_FAILURE;
  }
  return EXIT_SUCCESS;
}
