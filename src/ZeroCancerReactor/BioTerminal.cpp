/**
 * @file BioTerminal.cpp
 * @brief Implementation of the Cybernetic Log System
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 */

#include "Interface/BioTerminal.h"
#include <cstdarg>
#include <chrono>
#include <iomanip>
#include <sstream>

namespace ZeroCancerReactor {
    namespace Interface {

        BioTerminal::BioTerminal() : head_(0), count_(0) {
            logs_.resize(MAX_LOG_HISTORY);
        }

        void BioTerminal::AddLog(LogLevel level, const char* format, ...) {
            auto now = std::chrono::system_clock::now();
            auto in_time_t = std::chrono::system_clock::to_time_t(now);
            auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

            struct tm time_info;
            localtime_s(&time_info, &in_time_t);

            std::stringstream ss;
            ss << "[" << std::put_time(&time_info, "%H:%M:%S") << '.' << std::setfill('0') << std::setw(3) << ms.count() << "]";
            std::string ts_str = ss.str();

            char buffer[2048];
            va_list args;
            va_start(args, format);
            vsnprintf(buffer, sizeof(buffer), format, args);
            va_end(args);
            std::string msg_str(buffer);

            std::scoped_lock<std::mutex> lock(log_mtx_);

            LogEntry new_entry{ std::move(ts_str), std::move(msg_str), level };

            if (count_ < MAX_LOG_HISTORY) {
                logs_[count_] = std::move(new_entry);
                count_++;
            }
            else {
                logs_[head_] = std::move(new_entry);
                head_ = (head_ + 1) % MAX_LOG_HISTORY;
            }
        }

        std::vector<LogEntry> BioTerminal::GetRecentLogs() const {
            std::scoped_lock<std::mutex> lock(log_mtx_);
            std::vector<LogEntry> result;
            result.reserve(count_);

            for (size_t i = 0; i < count_; ++i) {
                size_t index = (count_ == MAX_LOG_HISTORY) ? ((head_ + i) % MAX_LOG_HISTORY) : i;
                result.push_back(logs_[index]);
            }
            return result;
        }

        void BioTerminal::Clear() {
            std::scoped_lock<std::mutex> lock(log_mtx_);
            head_ = 0;
            count_ = 0;
        }

    }
}