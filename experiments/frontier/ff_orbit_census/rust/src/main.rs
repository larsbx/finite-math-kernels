//! Rust baseline for u32-prime-field-orbit-v1 (see ../CONTRACT.md).
//!
//! Depth-first over the word tree, sharing prefixes, with the tree cut at a
//! fixed depth into independent subtrees that threads claim from a counter.
//!
//! Usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>

use std::env;
use std::io::Write;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::time::Instant;

type Vec4 = [u32; 4];

const H0: u32 = 0x9E37_79B9;
const CUT: usize = 6;

#[derive(Clone, Default)]
struct Record {
    words: u64,
    zero_hits: [u64; 4],
    first_zero: Option<u64>,
    hash_sum: u32,
    hash_xor: u32,
}

impl Record {
    fn merge(mut self, o: Record) -> Record {
        self.words += o.words;
        (0..4).for_each(|k| self.zero_hits[k] += o.zero_hits[k]);
        self.first_zero = match (self.first_zero, o.first_zero) {
            (Some(a), Some(b)) => Some(a.min(b)),
            (a, b) => a.or(b),
        };
        self.hash_sum = self.hash_sum.wrapping_add(o.hash_sum);
        self.hash_xor ^= o.hash_xor;
        self
    }
}

struct Census {
    p: u64,
    length: usize,
    seed: Vec4,
    stride: u64,
}

#[inline(always)]
fn mix32(mut x: u32) -> u32 {
    x ^= x >> 16;
    x = x.wrapping_mul(0x7FEB_352D);
    x ^= x >> 15;
    x = x.wrapping_mul(0x846C_A68B);
    x ^ (x >> 16)
}

impl Census {
    /// `x mod p` for `x < 2p`, by one conditional subtraction.
    #[inline(always)]
    fn fold(&self, x: u64) -> u64 {
        if x >= self.p { x - self.p } else { x }
    }

    /// `(2 * s - v_i) mod p` without division: every operand stays below `4p < 2^34`.
    #[inline(always)]
    fn step(&self, v: Vec4, i: usize) -> Vec4 {
        let s = self.fold(self.fold(v.iter().map(|&x| x as u64).sum::<u64>() - v[i] as u64));
        let d = self.fold(2 * s);
        let mut out = v;
        out[i] = self.fold(d + self.p - v[i] as u64) as u32;
        out
    }

    fn leaf(&self, rec: &mut Record, w: u64, e: Vec4) {
        let h = e.iter().fold(H0, |h, &x| mix32(h ^ x));
        rec.words += 1;
        (0..4).for_each(|k| rec.zero_hits[k] += (e[k] == 0) as u64);
        if e.contains(&0) && rec.first_zero.map_or(true, |f| w < f) {
            rec.first_zero = Some(w);
        }
        rec.hash_sum = rec.hash_sum.wrapping_add(h);
        rec.hash_xor ^= h;
    }

    /// The first `n` letters of word `w` (the contract's word indexing) applied to
    /// the seed: the last letter and the vector.
    fn descend(&self, n: usize, w: u64) -> (usize, Vec4) {
        let (mut last, mut q) = ((w % 4) as usize, w / 4);
        let mut v = self.step(self.seed, last);
        for _ in 1..n {
            let r = (q % 3) as usize;
            q /= 3;
            last = r + (r >= last) as usize;
            v = self.step(v, last);
        }
        (last, v)
    }

    /// Depth-first below one node: `n` levels left, `wt` the index weight of the next level.
    fn walk(&self, rec: &mut Record, n: usize, last: usize, w: u64, wt: u64, v: Vec4) {
        if n == 0 {
            return self.leaf(rec, w, v);
        }
        for r in 0..3 {
            let letter = r + (r >= last) as usize;
            self.walk(rec, n - 1, letter, w + r as u64 * wt, wt * 3, self.step(v, letter));
        }
    }

    /// The subtree below prefix number `t` of the `4 * 3^(cut-1)` prefixes of length `cut`.
    fn subtree(&self, cut: usize, t: u64) -> Record {
        let (last, v) = self.descend(cut, t);
        let mut rec = Record::default();
        self.walk(&mut rec, self.length - cut, last, t, 4 * 3u64.pow(cut as u32 - 1), v);
        rec
    }

    fn run(&self, threads: usize) -> (Record, Vec<(u64, Vec4)>) {
        let cut = CUT.min(self.length);
        let tasks = 4 * 3u64.pow(cut as u32 - 1);
        let next = AtomicUsize::new(0);
        let parts: Vec<Record> = std::thread::scope(|s| {
            let workers: Vec<_> = (0..threads)
                .map(|_| {
                    s.spawn(|| {
                        let mut acc = Record::default();
                        loop {
                            let t = next.fetch_add(1, Ordering::Relaxed) as u64;
                            if t >= tasks {
                                return acc;
                            }
                            acc = acc.merge(self.subtree(cut, t));
                        }
                    })
                })
                .collect();
            workers.into_iter().map(|h| h.join().unwrap()).collect()
        });
        let rec = parts.into_iter().fold(Record::default(), Record::merge);
        // Samples are recomputed from their indices rather than tested for at every leaf.
        let samples = (0..rec.words).step_by(self.stride as usize).map(|w| (w, self.descend(self.length, w).1)).collect();
        (rec, samples)
    }
}

fn render(c: &Census, r: &Record, samples: &[(u64, Vec4)]) -> String {
    let mut out = format!(
        "contract u32-prime-field-orbit-v1\np {}\nlength {}\nwords {}\nzero_hits {} {} {} {}\nfirst_zero {}\nhash_sum {}\nhash_xor {}\n",
        c.p, c.length, r.words, r.zero_hits[0], r.zero_hits[1], r.zero_hits[2], r.zero_hits[3],
        r.first_zero.map_or("none".to_string(), |w| w.to_string()), r.hash_sum, r.hash_xor
    );
    for (w, e) in samples {
        out += &format!("sample {} {} {} {} {}\n", w, e[0], e[1], e[2], e[3]);
    }
    out
}

fn main() {
    let a: Vec<u64> = env::args().skip(1).map(|s| s.parse().expect("integer argument")).collect();
    assert!(a.len() == 8, "usage: census <p> <length> <s0> <s1> <s2> <s3> <stride> <threads>");
    let (p, length) = (a[0], a[1] as usize);
    assert!(p > 2 && p < 1 << 32 && p % 2 == 1 && length >= 1 && a[6] >= 1 && a[7] >= 1);
    let seed = [a[2], a[3], a[4], a[5]].map(|x| (x % p) as u32);
    let census = Census { p, length, seed, stride: a[6] };
    let start = Instant::now();
    let (rec, samples) = census.run(a[7] as usize);
    let ns = start.elapsed().as_nanos();
    std::io::stdout().write_all(render(&census, &rec, &samples).as_bytes()).unwrap();
    eprintln!("kernel_ns {ns}");
}
