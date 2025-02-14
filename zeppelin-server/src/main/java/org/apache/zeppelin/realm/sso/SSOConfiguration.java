package org.apache.zeppelin.realm.sso;

import com.mapr.web.security.SslConfig;
import com.mapr.web.security.WebSecurityManager;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.JWSKeySelector;
import com.nimbusds.jose.proc.JWSVerificationKeySelector;
import com.nimbusds.jose.proc.SecurityContext;
import com.nimbusds.jose.util.DefaultResourceRetriever;
import com.nimbusds.jose.util.ResourceRetriever;
import com.nimbusds.jwt.proc.ConfigurableJWTProcessor;
import com.nimbusds.jwt.proc.DefaultJWTProcessor;
import com.nimbusds.oauth2.sdk.Scope;
import com.nimbusds.oauth2.sdk.auth.Secret;
import com.nimbusds.oauth2.sdk.http.HTTPRequest;
import com.nimbusds.oauth2.sdk.id.ClientID;
import com.nimbusds.oauth2.sdk.id.Issuer;
import com.nimbusds.oauth2.sdk.util.tls.TLSUtils;
import com.nimbusds.openid.connect.sdk.op.OIDCProviderMetadata;
import com.nimbusds.openid.connect.sdk.validators.IDTokenValidator;
import org.apache.hadoop.security.authentication.util.SsoConfigurationUtil;

import javax.net.ssl.SSLSocketFactory;
import java.io.InputStream;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyStore;

/**
 * A convenient wrapper around {@link SsoConfigurationUtil} singleton, providing access to
 * configured entities from nimbus-jose-jwt & oauth2-oidc-sdk libraries to process JWT and
 * perform OIDC authentication flow.
 * This is a singleton that can only be instantiated if SSO is enabled on cluster, which is
 * determined by the presence of SSO config (maprcli cluster getssoconfig),
 * otherwise exception is thrown.
 */
public class SSOConfiguration {

  public static final boolean IS_ENABLED = SsoConfigurationUtil.getInstance().isSsoEnabled();

  public static final Scope SCOPE = new Scope("openid");

  private final OIDCProviderMetadata oidcProviderMetadata;
  private final String usernameJwtClaim;

  private final ClientID clientID;
  private final Secret clientSecret;
  private final JWSAlgorithm jwsAlgorithm;

  private final ConfigurableJWTProcessor<SecurityContext> jwtProcessor;
  private final IDTokenValidator idTokenValidator;

  private static SSOConfiguration instance;

  public static SSOConfiguration getInstance() {
    if (instance == null) {
      try {
        instance = new SSOConfiguration();
      } catch (Exception e) {
        throw new RuntimeException("Could not instantiate SSOConfiguration", e);
      }
    }
    return instance;
  }

  private SSOConfiguration() throws Exception {
    if (!IS_ENABLED) {
      throw new IllegalStateException("Attempt to instantiate SSOConfiguration when SSO is disabled");
    }

    SsoConfigurationUtil ssoConfig = SsoConfigurationUtil.getInstance();

    SSLSocketFactory sslSocketFactory = createSSLSocketFactory();
    HTTPRequest.setDefaultSSLSocketFactory(sslSocketFactory);
    ResourceRetriever resourceRetriever = createSslResourceRetriever(sslSocketFactory);

    Issuer issuer = new Issuer(ssoConfig.getClientIssuer());
    oidcProviderMetadata = OIDCProviderMetadata.resolve(issuer);
    usernameJwtClaim = ssoConfig.getUserAttrName();

    clientID = new ClientID(ssoConfig.getClientId());
    clientSecret = new Secret(ssoConfig.getClientSecret());
    jwsAlgorithm = JWSAlgorithm.parse(ssoConfig.getJwsSsoAlgorithm());

    URL jwksURL = oidcProviderMetadata.getJWKSetURI().toURL();
    JWKSource<SecurityContext> jwkSource = JWKSourceBuilder.create(jwksURL, resourceRetriever).build();
    JWSKeySelector<SecurityContext> jwsKeySelector = new JWSVerificationKeySelector<>(jwsAlgorithm, jwkSource);

    jwtProcessor = new DefaultJWTProcessor<>();
    jwtProcessor.setJWSKeySelector(jwsKeySelector);

    idTokenValidator = new IDTokenValidator(issuer, clientID, jwsKeySelector, null);
  }

  public OIDCProviderMetadata getOidcProviderMetadata() {
    return oidcProviderMetadata;
  }

  public String getUsernameJwtClaim() {
    return usernameJwtClaim;
  }

  public ClientID getClientID() {
    return clientID;
  }

  public Secret getClientSecret() {
    return clientSecret;
  }

  public JWSAlgorithm getJwsAlgorithm() {
    return jwsAlgorithm;
  }

  public ConfigurableJWTProcessor<SecurityContext> getJwtProcessor() {
    return jwtProcessor;
  }

  public IDTokenValidator getIdTokenValidator() {
    return idTokenValidator;
  }

  private static SSLSocketFactory createSSLSocketFactory() throws Exception {
    try (SslConfig sslConfig = WebSecurityManager.getSslConfig()) {
      KeyStore trustStore = KeyStore.getInstance(sslConfig.getServerTruststoreType());
      InputStream trustStoreInputStream = Files.newInputStream(Paths.get(sslConfig.getServerTruststoreLocation()));
      trustStore.load(trustStoreInputStream, sslConfig.getServerTruststorePassword());
      return TLSUtils.createSSLSocketFactory(trustStore);
    }
  }

  private static ResourceRetriever createSslResourceRetriever(SSLSocketFactory sslSocketFactory) {
    return new DefaultResourceRetriever(JWKSourceBuilder.DEFAULT_HTTP_CONNECT_TIMEOUT,
            JWKSourceBuilder.DEFAULT_HTTP_READ_TIMEOUT,
            JWKSourceBuilder.DEFAULT_HTTP_SIZE_LIMIT,
            true,
            sslSocketFactory);
  }
}
