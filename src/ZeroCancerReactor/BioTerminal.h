/**
 * @file BioTerminal.h
 * @brief Real-time Cybernetic Bio-Log System (Phase 36: Final Integration)
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 */

#pragma once

#include <string>
#include <vector>
#include <mutex>

namespace ZeroCancerReactor {
    namespace Interface {

        enum class LogLevel {
            INFO,
            WARNING,
            CRITICAL,
            SYSTEM_DEAD
        };

        struct LogEntry {
            std::string timestamp;
            std::string message;
            LogLevel level;
        };

        class BioTerminal {
        private:
            std::vector<LogEntry> logs_;
            size_t head_;
            size_t count_;
            mutable std::mutex log_mtx_;

            static constexpr size_t MAX_LOG_HISTORY = 200;

        public:
            BioTerminal();
            ~BioTerminal() = default;

            void AddLog(LogLevel level, const char* format, ...);
            std::vector<LogEntry> GetRecentLogs() const;
            void Clear();
        };

    }
}