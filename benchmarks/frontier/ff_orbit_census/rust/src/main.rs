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
    samples: Vec<(u64, Vec4)>,
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
        self.samples.extend(o.samples);
        self
    }
}

struct Census {
    p: u64,
    length: usize,
    seed: Vec4,
    stride: u64,
    weight: Vec<u64>, // weight[k] = index contribution of residue r at depth k: 1 at k = 0, else 4 * 3^(k-1)
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
    #[inline(always)]
    fn step(&self, v: Vec4, i: usize) -> Vec4 {
        let s = (v.iter().map(|&x| x as u64).sum::<u64>() - v[i] as u64) % self.p;
        let mut out = v;
        out[i] = ((2 * s + 2 * self.p - v[i] as u64) % self.p) as u32;
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
        if w % self.stride == 0 {
            rec.samples.push((w, e));
        }
    }

    fn walk(&self, rec: &mut Record, depth: usize, last: usize, w: u64, v: Vec4) {
        if depth == self.length {
            return self.leaf(rec, w, v);
        }
        for r in 0..3 {
            let letter = r + (r >= last) as usize;
            self.walk(rec, depth + 1, letter, w + r as u64 * self.weight[depth], self.step(v, letter));
        }
    }

    /// The subtree below prefix number `t` of the `4 * 3^(cut-1)` prefixes of length `cut`.
    fn subtree(&self, cut: usize, t: u64) -> Record {
        let (mut v, mut last, mut q) = (self.step(self.seed, (t % 4) as usize), (t % 4) as usize, t / 4);
        for _ in 1..cut {
            let r = (q % 3) as usize;
            q /= 3;
            last = r + (r >= last) as usize;
            v = self.step(v, last);
        }
        let mut rec = Record::default();
        self.walk(&mut rec, cut, last, t, v);
        rec
    }

    fn run(&self, threads: usize) -> Record {
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
        let mut rec = parts.into_iter().fold(Record::default(), Record::merge);
        rec.samples.sort_unstable();
        rec
    }
}

fn render(c: &Census, r: &Record) -> String {
    let mut out = format!(
        "contract u32-prime-field-orbit-v1\np {}\nlength {}\nwords {}\nzero_hits {} {} {} {}\nfirst_zero {}\nhash_sum {}\nhash_xor {}\n",
        c.p, c.length, r.words, r.zero_hits[0], r.zero_hits[1], r.zero_hits[2], r.zero_hits[3],
        r.first_zero.map_or("none".to_string(), |w| w.to_string()), r.hash_sum, r.hash_xor
    );
    for (w, e) in &r.samples {
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
    let weight = (0..length).map(|k| if k == 0 { 1 } else { 4 * 3u64.pow(k as u32 - 1) }).collect();
    let census = Census { p, length, seed, stride: a[6], weight };
    let start = Instant::now();
    let rec = census.run(a[7] as usize);
    let ns = start.elapsed().as_nanos();
    std::io::stdout().write_all(render(&census, &rec).as_bytes()).unwrap();
    eprintln!("kernel_ns {ns}");
}
