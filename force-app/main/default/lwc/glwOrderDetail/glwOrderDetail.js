import { LightningElement, api, wire } from 'lwc';
import getOrderDetail from '@salesforce/apex/GLW_OrderController.getOrderDetail';
import requestOrderWeather from '@salesforce/apex/GLW_OrderController.requestOrderWeather';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

export default class GlwOrderDetail extends LightningElement {
    @api orderId;

    order;
    error;
    wiredResult;
    showItemCreate = false;
    showItemEdit = false;
    selectedItemId;
    weatherRequested = false;

    @wire(getOrderDetail, { orderId: '$orderId' })
    wiredDetail(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.order = data;
            this.error = undefined;
            // On first successful load, request weather update once
            if (!this.weatherRequested && this.orderId) {
                this.weatherRequested = true;
                requestOrderWeather({ orderId: this.orderId })
                    .then(() => {
                        // refresh after a short delay to reflect updated weather fields
                        window.setTimeout(() => this.refresh(), 1500);
                    })
                    .catch(() => {
                        // ignore errors; UI still shows existing values
                    });
            }
        } else if (error) {
            this.error = error;
            this.order = undefined;
        }
    }

    get itemRows() {
        return this.order && this.order.items ? this.order.items : [];
    }

    itemColumns = [];

    connectedCallback() {
        this.itemColumns = [
            { label: 'Product', fieldName: 'productName', type: 'text' },
            { label: 'Quantity', fieldName: 'quantity', type: 'number' },
            { label: 'Unit Price', fieldName: 'unitPrice', type: 'currency' },
            { label: 'Total', fieldName: 'total', type: 'currency' },
            { type: 'action', typeAttributes: { rowActions: this.getItemRowActions } }
        ];
    }

    getItemRowActions(row, doneCallback) {
        const actions = [
            { label: 'Edit', name: 'edit' },
            { label: 'Delete', name: 'delete' }
        ];
        doneCallback(actions);
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

    // UI actions for items
    openItemCreate() {
        this.showItemCreate = true;
    }

    closeItemCreate() {
        this.showItemCreate = false;
    }

    openItemEdit(id) {
        this.selectedItemId = id;
        this.showItemEdit = true;
    }

    closeItemEdit() {
        this.showItemEdit = false;
        this.selectedItemId = undefined;
    }

    // Datatable row action handler
    handleItemRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.openItemEdit(row.id);
        } else if (action === 'delete') {
            this.deleteItem(row.id);
        }
    }

    async deleteItem(id) {
        try {
            // eslint-disable-next-line no-alert
            const ok = window.confirm('Delete this order item?');
            if (!ok) return;
            await deleteRecord(id);
            this.dispatchEvent(new ShowToastEvent({ title: 'Deleted', message: 'Order item deleted', variant: 'success' }));
            await this.refresh();
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Error deleting', message: (e && e.body && e.body.message) ? e.body.message : 'Unknown error', variant: 'error' }));
        }
    }

    async handleItemCreateSubmit(event) {
        // Ensure parent order is set
        event.preventDefault();
        const fields = event.detail.fields;
        fields.GLW_Order__c = this.order.orderId;
        this.template.querySelector('lightning-record-edit-form[data-id="createItemForm"]').submit(fields);
    }

    async handleItemCreateSuccess() {
        this.closeItemCreate();
        this.dispatchEvent(new ShowToastEvent({ title: 'Created', message: 'Order item created', variant: 'success' }));
        await this.refresh();
    }

    async handleItemEditSuccess() {
        this.closeItemEdit();
        this.dispatchEvent(new ShowToastEvent({ title: 'Updated', message: 'Order item updated', variant: 'success' }));
        await this.refresh();
    }

    async refresh() {
        if (this.wiredResult) {
            await refreshApex(this.wiredResult);
        }
    }

    // Weather is requested automatically on first load; no button needed
}
