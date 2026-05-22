package com.elasticsearch.demo.repository

import com.elasticsearch.demo.model.ProductDocument
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.elasticsearch.annotations.Query
import org.springframework.data.elasticsearch.repository.ElasticsearchRepository
import java.time.Instant

interface ProductSearchRepository : ElasticsearchRepository<ProductDocument, Long> {

    fun findByPriceBetween(min: Double, max: Double): List<ProductDocument>
    fun findByCreatedAtAfter(time: Instant): List<ProductDocument>

    // 全文搜尋，明確指定走 match + searchAnalyzer
    @Query(
        value = """
            {
              "multi_match": {
                "query": "?0",
                "fields": ["name^2", "description"],
                "type": "best_fields"
              }
            }
        """
    )
    fun fullTextSearch(keyword: String): List<ProductDocument>

    // 精確匹配，明確指定走 .keyword
    @Query("""{"term": {"name.keyword": "?0"}}""")
    fun findByExactName(name: String): List<ProductDocument>

    // name 模糊查詢，AUTO 會依字串長度自動決定容錯距離
    // 例如搜尋 "iphoen" 可以找到 "iphone"
    @Query(
        value = """
            {
              "match": {
                "name": {
                  "query": "?0",
                  "fuzziness": "AUTO"
                }
              }
            }
        """
    )
    fun fuzzySearchByName(keyword: String): List<ProductDocument>

    // name + description 同時模糊查詢
    @Query(
        value = """
            {
              "multi_match": {
                "query": "?0",
                "fields": ["name^2", "description"],
                "fuzziness": "AUTO"
              }
            }
        """
    )
    fun fuzzySearchAll(keyword: String): List<ProductDocument>

    @Query(
        value = """
            {
              "match": {
                "name": {
                  "query": "?0"
                }
              }
            }
        """
    )
    fun searchPageByName(keyword: String, pageable: Pageable): Page<ProductDocument>

}
