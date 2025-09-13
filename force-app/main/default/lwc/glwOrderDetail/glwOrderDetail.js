import { LightningElement, api, wire } from 'lwc';
import getOrderDetail from '@salesforce/apex/GLW_OrderController.getOrderDetail';

export default class GlwOrderDetail extends LightningElement {
    @api orderId;

    order;
    error;

    @wire(getOrderDetail, { orderId: '$orderId' })
    wiredDetail({ data, error }) {
        if (data) {
            this.order = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.order = undefined;
        }
    }

    get itemRows() {
        return this.order && this.order.items ? this.order.items : [];
    }

    get itemColumns() {
        return [
            { label: 'Product', fieldName: 'productName', type: 'text' },
            { label: 'Quantity', fieldName: 'quantity', type: 'number' },
            { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
            { label: 'Total', fieldName: 'total', type: 'currency' }
        ];
    }

    get customerName() {
        if (!this.order) return '';
        const parts = [];
        if (this.order.customerFirstName) parts.push(this.order.customerFirstName);
        if (this.order.customerLastName) parts.push(this.order.customerLastName);
        return parts.length ? parts.join(' ') : this.order.customerName;
    }

    get errorMessage() {
        if (!this.error) return '';
        // Attempt to extract a friendly message
        const body = this.error.body;
        if (body && body.message) return body.message;
        try {
            return JSON.stringify(this.error);
        } catch (e) {
            return 'An unexpected error occurred loading order details.';
        }
    }
}
