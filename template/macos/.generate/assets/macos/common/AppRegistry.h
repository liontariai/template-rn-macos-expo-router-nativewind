#ifndef COMMON_APPREGISTRY_
#define COMMON_APPREGISTRY_

#include <string>
#include <vector>

namespace facebook::jsi
{
    class Runtime;
}

namespace TemplateProject
{
    /**
     * Returns app keys registered in `AppRegistry`.
     */
    std::vector<std::string> GetAppKeys(facebook::jsi::Runtime &runtime);
}  // namespace TemplateProject

#endif  // COMMON_APPREGISTRY_
