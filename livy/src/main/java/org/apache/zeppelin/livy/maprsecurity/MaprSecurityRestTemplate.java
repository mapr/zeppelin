package org.apache.zeppelin.livy.maprsecurity;

import org.apache.hc.client5.http.auth.AuthSchemeFactory;
import org.apache.hc.client5.http.auth.AuthScope;
import org.apache.hc.client5.http.auth.Credentials;
import org.apache.hc.client5.http.classic.HttpClient;
import org.apache.hc.client5.http.config.RequestConfig;
import org.apache.hc.client5.http.impl.auth.BasicCredentialsProvider;
import org.apache.hc.client5.http.impl.classic.CloseableHttpClient;
import org.apache.hc.client5.http.impl.classic.HttpClientBuilder;
import org.apache.hc.core5.http.config.Lookup;
import org.apache.hc.core5.http.config.RegistryBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.security.Principal;
import java.util.Arrays;
import java.util.Collections;

public class MaprSecurityRestTemplate extends RestTemplate {

  private static final Logger logger = LoggerFactory.getLogger(MaprSecurityRestTemplate.class);

  private static final Credentials credentials = new MaprSecurityRestTemplate.NullCredentials();

  public MaprSecurityRestTemplate() {
    this(buildHttpClient());
  }

  public MaprSecurityRestTemplate(HttpClient httpClient) {
    super(new HttpComponentsClientHttpRequestFactory(httpClient));
  }

  private static HttpClient buildHttpClient() {
    HttpClientBuilder builder = HttpClientBuilder.create();

    builder = configureHttpClientBuilder(builder);

    CloseableHttpClient httpClient = builder.build();
    return httpClient;
  }

  public static HttpClientBuilder configureHttpClientBuilder(HttpClientBuilder builder) {
    logger.info("Creating custom MapR Rest template");
    Lookup<AuthSchemeFactory> authSchemeRegistry = RegistryBuilder.<AuthSchemeFactory> create()
            .register(MaprSecurityScheme.NAME, new MaprSecuritySchemeFactory()).build();
    builder.setDefaultAuthSchemeRegistry(authSchemeRegistry);

    RequestConfig.Builder rc = RequestConfig.custom();
    rc.setTargetPreferredAuthSchemes(
            Collections.unmodifiableList(Arrays.asList(MaprSecurityScheme.NAME)));
    builder.setDefaultRequestConfig(rc.build());

    BasicCredentialsProvider credentialsProvider = new BasicCredentialsProvider();
    credentialsProvider.setCredentials(new AuthScope(null, -1), credentials);
    builder.setDefaultCredentialsProvider(credentialsProvider);

    return builder;
  }

  private static class NullCredentials implements Credentials {

    @Override
    public Principal getUserPrincipal() {
      return null;
    }

    @Override
    public char[] getPassword() {
      return null;
    }

  }

}
