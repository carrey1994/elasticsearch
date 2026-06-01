package com.elasticsearch.demo.repository

import com.elasticsearch.demo.model.Product
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface ProductRepository : JpaRepository<Product, Long> {
    fun findAllByIdGreaterThan(id: Long): List<Product>
}
