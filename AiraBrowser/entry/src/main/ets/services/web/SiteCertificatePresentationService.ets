import { util } from '@kit.ArkTS';
import { cert } from '@kit.DeviceCertificateKit';
import { BrowserRuntimeLifecyclePort } from './BrowserRuntimeLifecyclePort';

export interface SiteCertificatePresentationRuntimeContext {
  controllerAttached: boolean;
  secureCurrentSite: boolean;
  currentSiteHost: string;
}

export interface SiteCertificatePresentationState {
  summary: ResourceStr;
  detailStatus: ResourceStr;
  subject: string;
  issuer: string;
  validFrom: string;
  validTo: string;
  serialNumber: string;
  signatureAlgorithm: string;
  chainCount: number;
}

export class SiteCertificatePresentationService {
  buildLoadingState(): SiteCertificatePresentationState {
    const loadingText = $r('app.string.settings_site_certificate_loading');
    return this.buildState(loadingText, loadingText);
  }

  async resolveCurrentStateFromLifecyclePort(
    runtimeLifecyclePort: BrowserRuntimeLifecyclePort,
    context: SiteCertificatePresentationRuntimeContext
  ): Promise<SiteCertificatePresentationState> {
    if (!context.controllerAttached) {
      return this.buildUnavailableState($r('app.string.settings_site_certificate_unavailable_not_loaded'));
    }
    if (!context.secureCurrentSite) {
      return this.buildUnavailableState($r('app.string.settings_site_certificate_unavailable_insecure'));
    }

    const controller = runtimeLifecyclePort.resolveActiveController();
    if (controller === undefined) {
      return this.buildUnavailableState($r('app.string.settings_site_certificate_unavailable_failed'));
    }
    try {
      const certificates = await controller.getCertificate();
      if (certificates.length === 0) {
        return this.buildUnavailableState($r('app.string.settings_site_certificate_unavailable_missing'));
      }
      return this.buildLoadedState(certificates[0], certificates.length, context.currentSiteHost);
    } catch (_error) {
      return this.buildUnavailableState($r('app.string.settings_site_certificate_unavailable_failed'));
    }
  }

  buildUnavailableState(status: ResourceStr): SiteCertificatePresentationState {
    return this.buildState(status, status);
  }

  buildLoadedState(
    certificate: cert.X509Cert,
    chainLength: number,
    fallbackSubject: string
  ): SiteCertificatePresentationState {
    const issuer = this.readCertificateIssuer(certificate);
    const validTo = this.formatCertificateDate(this.readCertificateNotAfterTime(certificate));
    return {
      summary: this.buildCertificateSummary(issuer, validTo, chainLength),
      detailStatus: $r('app.string.settings_site_certificate_ready_status'),
      subject: this.readCertificateSubject(certificate, fallbackSubject),
      issuer: issuer,
      validFrom: this.formatCertificateDate(this.readCertificateNotBeforeTime(certificate)),
      validTo: validTo,
      serialNumber: this.readCertificateSerialNumber(certificate),
      signatureAlgorithm: this.readCertificateSignatureAlgorithm(certificate),
      chainCount: chainLength
    };
  }

  buildChainDetailText(chainCount: number): ResourceStr {
    if (chainCount <= 0) {
      return '';
    }
    return $r('app.string.settings_site_certificate_chain_count', chainCount);
  }

  private buildState(summary: ResourceStr, detailStatus: ResourceStr): SiteCertificatePresentationState {
    return {
      summary: summary,
      detailStatus: detailStatus,
      subject: '',
      issuer: '',
      validFrom: '',
      validTo: '',
      serialNumber: '',
      signatureAlgorithm: '',
      chainCount: 0
    };
  }

  private buildCertificateSummary(issuer: string, validUntil: string, chainLength: number): ResourceStr {
    const hasChain = chainLength > 1;
    if (issuer.length > 0 && validUntil.length > 0) {
      return hasChain
        ? $r('app.string.settings_site_certificate_summary_issued_valid_chain', issuer, validUntil, chainLength)
        : $r('app.string.settings_site_certificate_summary_issued_valid', issuer, validUntil);
    }
    if (validUntil.length > 0) {
      return hasChain
        ? $r('app.string.settings_site_certificate_summary_valid_chain', validUntil, chainLength)
        : $r('app.string.settings_site_certificate_summary_valid', validUntil);
    }
    if (issuer.length > 0) {
      return hasChain
        ? $r('app.string.settings_site_certificate_summary_issued_chain', issuer, chainLength)
        : $r('app.string.settings_site_certificate_summary_issued', issuer);
    }
    return hasChain
      ? $r('app.string.settings_site_certificate_summary_ready_chain', chainLength)
      : $r('app.string.settings_site_certificate_summary_ready');
  }

  private readCertificateIssuer(certificate: cert.X509Cert): string {
    try {
      return this.extractCertificateCommonName(certificate.getIssuerName(cert.EncodingType.ENCODING_UTF8));
    } catch (_error) {
      return '';
    }
  }

  private readCertificateSubject(certificate: cert.X509Cert, fallbackSubject: string): string {
    try {
      return this.extractCertificateCommonName(
        this.decodeCertificateData(certificate.getSubjectName(cert.EncodingType.ENCODING_UTF8))
      );
    } catch (_error) {
      return fallbackSubject;
    }
  }

  private decodeCertificateData(data: cert.DataBlob): string {
    try {
      return util.TextDecoder.create('utf-8').decodeToString(data.data).trim();
    } catch (_error) {
      return '';
    }
  }

  private readCertificateNotBeforeTime(certificate: cert.X509Cert): string {
    try {
      return certificate.getNotBeforeTime();
    } catch (_error) {
      return '';
    }
  }

  private readCertificateNotAfterTime(certificate: cert.X509Cert): string {
    try {
      return certificate.getNotAfterTime();
    } catch (_error) {
      return '';
    }
  }

  private readCertificateSerialNumber(certificate: cert.X509Cert): string {
    try {
      return certificate.getCertSerialNumber().toString();
    } catch (_error) {
      return '';
    }
  }

  private readCertificateSignatureAlgorithm(certificate: cert.X509Cert): string {
    try {
      return certificate.getSignatureAlgName();
    } catch (_error) {
      return '';
    }
  }

  private extractCertificateCommonName(name: string): string {
    const commonNameMatch = name.match(/(?:^|,)\s*CN\s*=\s*([^,]+)/i);
    if (commonNameMatch !== null) {
      return commonNameMatch[1].trim();
    }
    const organizationMatch = name.match(/(?:^|,)\s*O\s*=\s*([^,]+)/i);
    if (organizationMatch !== null) {
      return organizationMatch[1].trim();
    }
    return name.trim();
  }

  private formatCertificateDate(value: string): string {
    const match = value.match(/^(\d{4})[-/年]?(\d{1,2})[-/月]?(\d{1,2})/);
    if (match !== null) {
      return `${match[1]}-${this.padTwoDigits(match[2])}-${this.padTwoDigits(match[3])}`;
    }
    return value.trim();
  }

  private padTwoDigits(value: string): string {
    return value.length >= 2 ? value : `0${value}`;
  }
}
