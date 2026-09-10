/**
 * @file CMR_engine.hpp
 * @brief Compressed Manifold Reachability (CMR) Engine
 * @author Jonathan f(n) Reed
 * @license GNU Affero General Public License v3.0 (AGPL-3.0)
 */

#ifndef CMR_ENGINE_HPP
#define CMR_ENGINE_HPP

#include <vector>
#include <cmath>
#include <algorithm>
#include <functional>
#include <stdexcept>

namespace cmr {

/**
 * @struct MatrixR
 * @brief Lightweight r x r Matrix structure mirroring Lean's Matrix (Fin r) (Fin r) ℝ.
 */
struct MatrixR {
    size_t r;
    std::vector<double> data;

    explicit MatrixR(size_t rank) : r(rank), data(rank * rank, 0.0) {}

    double& at(size_t i, size_t j) {
        return data[i * r + j];
    }

    double at(size_t i, size_t j) const {
        return data[i * r + j];
    }

    static MatrixR identity(size_t rank) {
        MatrixR mat(rank);
        for (size_t i = 0; i < rank; ++i) {
            mat.at(i, i) = 1.0;
        }
        return mat;
    }

    MatrixR multiply(const MatrixR& other) const {
        MatrixR result(r);
        for (size_t i = 0; i < r; ++i) {
            for (size_t k = 0; k < r; ++k) {
                double aik = at(i, k);
                if (aik == 0.0) continue;
                for (size_t j = 0; j < r; ++j) {
                    result.at(i, j) += aik * other.at(k, j);
                }
            }
        }
        return result;
    }
};

/**
 * @brief Prong 1: Tensor-Train Core Chain Structure (Exact mapping to Lean TT_CoreChainStructure).
 * @tparam CoreGenerator Callable type generating core matrices per dimension.
 */
template <typename CoreGenerator>
inline double evaluateTT_CoreChain(size_t d, size_t rank_bound, CoreGenerator core_gen, const std::vector<double>& x) {
    if (x.size() < d) {
        throw std::invalid_argument("State vector dimension mismatch with d");
    }
    MatrixR finalMatrix = MatrixR::identity(rank_bound);
    for (size_t i = 0; i < d; ++i) {
        MatrixR coreMat = core_gen(i, x[i], rank_bound);
        finalMatrix = finalMatrix.multiply(coreMat);
    }
    return finalMatrix.at(0, 0);
}

/**
 * @brief Prong 2: Local Deterministic Base Subspace Solver (Lax-Friedrichs update).
 */
inline double localSubspaceUpdate(double v_k, double h_val, double dt) {
    return v_k - dt * h_val;
}

/**
 * @brief Prong 3: Max-Plus Global Synthesis Fabric (v1 <= v2 -> max(v1) <= max(v2)).
 */
inline double maxPlusSynthesis(const std::vector<double>& subspace_values) {
    if (subspace_values.empty()) return -INFINITY;
    double max_val = -INFINITY;
    for (double val : subspace_values) {
        if (val > max_val) {
            max_val = val;
        }
    }
    return max_val;
}

/**
 * @brief Master Update Equation Step: V^(n+1)(x) = P_TT (bigoplus (V_k - dt * H_k)).
 * @tparam CoreGenerator Callable type for tensor-train adaptive core projection.
 */
template <typename CoreGenerator>
inline double masterEquationStep(
    size_t d,
    size_t rank_bound,
    double dt,
    const std::vector<double>& x,
    const std::vector<double>& local_v,
    const std::vector<double>& hamiltonians,
    CoreGenerator core_gen
) {
    std::vector<double> subspace_results(d);
    for (size_t i = 0; i < d; ++i) {
        subspace_results[i] = localSubspaceUpdate(local_v[i], hamiltonians[i], dt);
    }

    double synthesized_global = maxPlusSynthesis(subspace_results);

    auto projected_core_gen = [&](size_t i, double xi, size_t r) {
        MatrixR mat(r);
        double base_core_val = std::cos(xi) * (1.0 + synthesized_global / (d * rank_bound));
        for (size_t row = 0; row < r; ++row) {
            for (size_t col = 0; col < r; ++col) {
                mat.at(row, col) = (row == col) ? base_core_val : 0.01 * base_core_val;
            }
        }
        return mat;
    };

    return evaluateTT_CoreChain(d, rank_bound, projected_core_gen, x);
}

} // namespace cmr

#endif // CMR_ENGINE_HPP