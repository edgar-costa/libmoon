#include <mutex>
#include <condition_variable>
//#include <barrier>

struct barrier{
    std::mutex mutex;
    std::condition_variable cond;
    std::size_t n;
    std::size_t threshold;
    std::size_t generation;
};

extern "C" {
    struct barrier* make_barrier(size_t n){
        struct barrier *b = new barrier;
        b->n = n;
        b->threshold = n;
        b->generation = 0;
        return b;
    }

    void barrier_wait(struct barrier *b){
        std::unique_lock<std::mutex> lock{b->mutex};
        auto lgen = b->generation; 
        if ( --b->n == 0 ){
            b->generation++;
            b->n = b->threshold;
            b->cond.notify_all();
        }else{
            b->cond.wait(lock, [ = ] { return lgen != b->generation;});
        }
    }

    void barrier_reinit(struct barrier *b, size_t n){
        std::unique_lock<std::mutex> lock{b->mutex};
        b->n = n;
    }
}
